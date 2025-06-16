# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'
require 'review/ast/renderer'
require 'review/ast/performance_tracker'
require 'review/loggable'
require 'review/lineinput'
require 'review/ast/inline_processor'
require 'review/ast/block_processor'
require 'review/snapshot_location'
require 'review/ast/list_ast_processor'
require 'stringio'

module ReVIEW
  module AST
    # Compiler - Core AST compilation logic and coordination
    #
    # This class handles the main AST compilation flow, coordinating between
    # inline and block processors to build complete AST structures from Re:VIEW content.
    #
    # Responsibilities:
    # - Main AST compilation coordination
    # - Headline and paragraph AST building
    # - AST mode management and rendering coordination
    # - Document structure management
    class Compiler
      include Loggable

      def initialize(builder)
        @builder = builder

        # AST related
        @ast_root = nil
        @current_ast_node = nil
        @ast_renderer = nil

        # Processors for specialized AST handling - lazy initialization
        @inline_processor = nil
        @block_processor = nil
        @list_processor = nil

        @logger = ReVIEW.logger

        # Performance measurement
        @performance_tracker = PerformanceTracker.new(logger: @logger)
      end

      attr_reader :builder, :ast_root, :current_ast_node, :ast_renderer

      # Lazy-loaded processors
      def inline_processor
        @inline_processor ||= InlineProcessor.new(self)
      end

      def block_processor
        @block_processor ||= BlockProcessor.new(self)
      end

      def list_processor
        @list_processor ||= ListASTProcessor.new(self)
      end

      def compile_to_ast(chapter)
        @chapter = chapter
        # Create AST root with appropriate location
        # For test compatibility, use a special calculation for line numbers
        f = LineInput.new(StringIO.new(@chapter.content))

        # Initialize title to match JSONBuilder behavior
        title = @chapter.respond_to?(:title) ? @chapter.title : ''
        @ast_root = AST::DocumentNode.new(
          location: SnapshotLocation.new(@chapter.basename, f.lineno + 1),
          title: title
        )
        @current_ast_node = @ast_root
        @ast_renderer = Renderer.new(@builder)

        @performance_tracker.start_timing(:total_compilation_time)

        # Full AST mode: build complete AST without rendering
        do_compile_with_ast_building
        # In full AST mode, render the AST using the builder
        # (unless it's JSONBuilder which handles AST differently)
        unless @builder.class.name == 'ReVIEW::JSONBuilder'
          @ast_renderer.render(@ast_root)
        end

        # Record performance statistics
        @performance_tracker.end_timing(:total_compilation_time)
        @performance_tracker.log_statistics
      end

      def do_compile_with_ast_building
        # Full AST mode: parse the entire document into AST first
        f = LineInput.new(StringIO.new(@chapter.content))
        @lineno = 0

        # Build the complete AST structure
        while f.next?
          @lineno = f.lineno
          # Create a snapshot location that captures the current line number
          @current_location = SnapshotLocation.new(@chapter.basename, f.lineno + 1)
          line_content = f.peek
          case line_content
          when /\A\#@/
            f.gets # skip preprocessor directives
          when /\A=+[\[\s\{]/
            compile_headline_to_ast(f.gets)
          when /\A\s*\z/ # rubocop:disable Lint/DuplicateBranch
            f.gets # skip blank lines
          when %r{\A//}
            compile_block_command_to_ast(f)
          when /\A\s+\*\s/ # unordered list (must start with space)
            compile_ul_to_ast(f)
          when /\A\s+\d+\.\s/ # ordered list (must start with space)
            compile_ol_to_ast(f)
          when /\A\s+:\s/ # definition list (must start with space)
            compile_dl_to_ast(f)
          else
            compile_paragraph_to_ast(f)
          end
        end
      end

      # AST-specific compilation methods
      def compile_headline_to_ast(line)
        # Parse headline using same logic as compile_headline
        m = /\A(=+)(?:\[(.+?)\])?(?:\{(.+?)\})?(.*)/.match(line)
        level = m[1].size
        if level > 6 # MAX_HEADLINE_LEVEL
          raise CompileError, 'Invalid header: max headline level is 6'
        end

        m[2]
        label = m[3]
        caption = m[4].strip

        # For AST mode, we only handle simple headlines (no tagged sections for now)
        # Tagged sections - for now, just create a regular headline
        # TODO: Implement proper tagged section support in AST if needed
        node = AST::HeadlineNode.new(
          location: location,
          level: level,
          label: label,
          caption: caption
        )
        if level == 1 && @ast_root && @ast_root.title.nil?
          @ast_root.title = caption
        end
        @current_ast_node.add_child(node)
      end

      def compile_paragraph_to_ast(f)
        raw_lines = []
        f.until_match(%r{\A//|\A\#@}) do |line|
          break if line.strip.empty?

          raw_lines.push(line.sub(/^(\t+)\s*/) { |m| '<!ESCAPETAB!>' * m.size }.strip.gsub('<!ESCAPETAB!>', "\t"))
        end

        return if raw_lines.empty?

        node = AST::ParagraphNode.new(location: location)
        # Process inline elements within paragraph
        raw_lines.each { |line| inline_processor.parse_inline_elements(line, node) }

        @current_ast_node.add_child(node)
      end

      def compile_block_command_to_ast(f)
        name, args, lines = read_command(f)

        case name
        when :list, :listnum, :emlist, :emlistnum, :cmd, :source
          block_processor.compile_code_block_to_ast(name, args, lines)
        when :image, :indepimage, :numberlessimage
          block_processor.compile_image_to_ast(name, args)
        when :table, :emtable, :imgtable
          block_processor.compile_table_to_ast(name, args, lines)
        when :ul, :ol, :dl
          block_processor.compile_list_to_ast(name, lines)
        when :quote
          block_processor.compile_quote_to_ast(lines)
        when :note, :memo, :tip, :info, :warning, :important, :caution, :notice
          block_processor.compile_minicolumn_to_ast(name, args, lines)
        when :embed
          block_processor.compile_embed_to_ast(args, lines)
        when :read
          block_processor.compile_read_to_ast(lines)
        else
          # Fallback to original processing for unknown commands
          # This would need access to the original compiler's syntax_descriptor method
          # For now, create a generic node
          generic_node = AST::Node.new(location: location, type: name.to_s)
          @current_ast_node.add_child(generic_node)
        end
      end

      def ast_result
        @ast_root
      end

      # Compile unordered list to AST (delegates to list processor)
      def compile_ul_to_ast(f)
        list_processor.process_unordered_list(f)
      end

      # Compile ordered list to AST (delegates to list processor)
      def compile_ol_to_ast(f)
        list_processor.process_ordered_list(f)
      end

      # Compile definition list to AST (delegates to list processor)
      def compile_dl_to_ast(f)
        list_processor.process_definition_list(f)
      end

      # Build headline AST node
      def build_headline_ast(level, label, caption)
        node = AST::HeadlineNode.new(location: location, level: level, label: label, caption: caption)
        @current_ast_node.add_child(node)
      end

      # Build paragraph AST node
      def build_paragraph_ast(lines)
        node = AST::ParagraphNode.new(location: location)

        # Parse inline elements in each line and create child nodes
        lines.each do |line|
          inline_processor.parse_inline_elements(line, node)
        end

        @current_ast_node.add_child(node)
      end

      # Build unordered list AST - now using dedicated ListASTProcessor
      def build_ulist_ast(f)
        list_processor.process_unordered_list(f)
      end

      # Build ordered list AST - now using dedicated ListASTProcessor
      def build_olist_ast(f)
        list_processor.process_ordered_list(f)
      end

      # Build definition list AST - now using dedicated ListASTProcessor
      def build_dlist_ast(f)
        list_processor.process_definition_list(f)
      end

      # Delegate to block processor for block command AST building
      def build_block_command_ast(command_name, args, lines)
        block_processor.build_block_command_ast(command_name, args, lines)
      end

      # Helper methods that need to be accessible from processors
      def location
        @current_location || @builder.location
      end

      def add_child_to_current_node(node)
        @current_ast_node.add_child(node)
      end

      # Expose performance tracker for external access
      attr_reader :performance_tracker

      private

      def read_command(f)
        # Simplified implementation with proper arg parsing
        line = f.gets
        name = line.slice(/[a-z]+/).to_sym
        args = parse_args(line.sub(%r{\A//[a-z]+}, '').rstrip.chomp('{'), name)
        lines = block_open?(line) ? read_block(f) : nil
        [name, args, lines]
      end

      def block_open?(line)
        line.rstrip[-1, 1] == '{'
      end

      def read_block(f)
        buf = []
        f.until_match(%r{\A//\}}) do |line|
          buf.push(line.chomp) unless /\A\#@/.match?(line)
        end
        f.gets if f.peek.to_s.start_with?('//}') # discard terminator
        buf
      end

      def parse_args(str, _name = nil)
        return [] if str.empty?

        require 'strscan'
        scanner = StringScanner.new(str)
        words = []
        while word = scanner.scan(/(\[\]|\[.*?[^\\]\])/)
          w2 = word[1..-2].gsub(/\\(.)/) do
            ch = $1
            [']', '\\'].include?(ch) ? ch : '\\' + ch
          end
          words << w2
        end
        unless scanner.eos?
          # Handle error - would need access to error reporting
          return []
        end

        words
      end
    end
  end
end
