# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'
require 'review/ast/performance_tracker'
require 'review/loggable'
require 'review/lineinput'
require 'review/ast/inline_processor'
require 'review/ast/block_processor'
require 'review/snapshot_location'
require 'review/ast/list_processor'
require 'review/ast/footnote_node'

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
      # Factory method to create appropriate compiler based on file format
      def self.for_chapter(chapter)
        filename = chapter.respond_to?(:filename) ? chapter.filename : chapter.basename

        # Check file extension for format detection
        if filename&.end_with?('.md', '.markdown')
          require 'review/ast/markdown_compiler'
          MarkdownCompiler.new
        else
          # Default to Re:VIEW format
          new
        end
      end
      include Loggable

      def initialize
        # AST related
        @ast_root = nil
        @current_ast_node = nil

        # Processors for specialized AST handling - lazy initialization
        @inline_processor = nil
        @block_processor = nil
        @list_processor = nil

        @logger = ReVIEW.logger

        # Get config for debug output
        @config = {}

        # Performance measurement - check if enabled via environment or config
        performance_enabled = ENV['REVIEW_AST_PERFORMANCE'] == 'true' ||
                              (defined?(ReVIEW::Configure.values) &&
                               ReVIEW::Configure.values.dig('ast', 'performance') == true)
        @performance_tracker = PerformanceTracker.new(enabled: performance_enabled, logger: @logger)

        # Debug output if debug is enabled
        if ENV['REVIEW_DEBUG_AST'] == 'true'
          @logger.info("DEBUG: AST::Compiler initialized with performance_enabled: #{performance_enabled}")
        end
      end

      attr_reader :ast_root, :current_ast_node

      # Compile content string directly to AST
      def compile(content)
        # Create a temporary chapter-like object
        temp_chapter = Struct.new(:content, :basename, :title).new(content, 'temp', '')
        compile_to_ast(temp_chapter)
      end

      # Lazy-loaded processors
      def inline_processor
        @inline_processor ||= InlineProcessor.new(self)
      end

      def block_processor
        @block_processor ||= BlockProcessor.new(self)
      end

      def list_processor
        @list_processor ||= ListProcessor.new(self)
      end

      def compile_to_ast(chapter)
        @chapter = chapter
        # Create AST root with appropriate location
        # For test compatibility, use a special calculation for line numbers
        f = LineInput.from_string(@chapter.content)

        # Initialize title from chapter
        title = @chapter.respond_to?(:title) ? @chapter.title : ''
        @ast_root = AST::DocumentNode.new(
          location: SnapshotLocation.new(@chapter.basename, f.lineno + 1),
          title: title,
          chapter: @chapter
        )
        @current_ast_node = @ast_root

        @performance_tracker.start_timing(:total_compilation_time)

        # Full AST mode: build complete AST
        do_compile_with_ast_building

        # Record performance statistics
        @performance_tracker.end_timing(:total_compilation_time)

        # Post-process AST for noindent and olnum commands
        process_noindent_commands
        process_olnum_commands

        @performance_tracker.log_statistics

        # Return the compiled AST
        @ast_root
      end

      def do_compile_with_ast_building
        # Full AST mode: parse the entire document into AST first
        f = LineInput.from_string(@chapter.content)
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
          when /\A\s*\z/ # rubocop:disable Lint/DuplicateBranch # blank lines separate elements
            f.gets # consume blank line but don't create node
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

      def compile_headline_to_ast(line)
        # Parse headline using same logic as compile_headline
        # Handle both new syntax: = Caption{label} and old syntax: ={label} Caption
        m = /\A(=+)(?:\[(.+?)\])?(?:\{(.+?)\})?(.*?)(?:\{(.+?)\})?\s*\z/.match(line)
        level = m[1].size
        if level > 6 # MAX_HEADLINE_LEVEL
          raise CompileError, "Invalid header: max headline level is 6#{format_location_info}"
        end

        # m[2] is optional tag parameter (e.g., [column])
        tag = m[2]
        label = m[3] || m[5] # Label can be in position 3 (old syntax) or 5 (new syntax)
        caption = m[4].strip

        processed_caption = AST::CaptionNode.parse(
          caption,
          location: location,
          inline_processor: inline_processor
        )

        # Before creating new section, handle section nesting
        # Find appropriate parent level for this headline/section
        current_node = find_appropriate_parent_for_level(level)
        # Handle tagged sections
        if tag == 'column'
          node = AST::ColumnNode.new(
            location: location,
            level: level,
            label: label,
            caption: processed_caption,
            column_type: 'column',
            inline_processor: inline_processor
          )
          current_node.add_child(node)
          # Set column as current node so subsequent content becomes its children
          @current_ast_node = node
        else
          # Regular headline or unsupported tag
          node = AST::HeadlineNode.new(
            location: location,
            level: level,
            label: label,
            caption: processed_caption
          )
          if level == 1 && @ast_root && @ast_root.title.nil?
            @ast_root.title = caption
          end
          current_node.add_child(node)
          # For regular headlines, reset current node to document level
          @current_ast_node = @ast_root
        end
      end

      def compile_paragraph_to_ast(f)
        raw_lines = []
        f.until_match(%r{\A//|\A\#@}) do |line|
          break if line.strip.empty?

          # Remove trailing newline and process indentation/content
          processed_line = line.chomp.sub(/^(\t*)(.*)$/) { $1 + $2.rstrip }
          raw_lines.push(processed_line)
        end

        return if raw_lines.empty?

        # Create single paragraph node with multiple lines joined by \n
        # This matches Re:VIEW specification where only empty lines separate paragraphs
        node = AST::ParagraphNode.new(location: location)
        combined_text = raw_lines.join("\n") # Join lines with newline characters
        inline_processor.parse_inline_elements(combined_text, node)
        @current_ast_node.add_child(node)
      end

      def compile_block_command_to_ast(f) # rubocop:disable Metrics/CyclomaticComplexity
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
        when :note, :memo, :tip, :info, :warning, :important, :caution, :notice
          block_processor.compile_minicolumn_to_ast(name, args, lines)
        when :embed
          block_processor.compile_embed_to_ast(args, lines)
        when :read, :quote, :blockquote, :lead, :centering, :flushright, :address, :talk
          block_processor.compile_block_to_ast(lines, name)
        when :doorquote, :bibpaper, :graph, :box
          block_processor.build_block_command_ast(name, args, lines)
        when :raw
          # For raw blocks, use EmbedNode
          node = AST::EmbedNode.new(
            location: location,
            embed_type: :raw,
            arg: args && args[0],
            lines: lines
          )
          @current_ast_node.add_child(node)
        when :comment
          # Comment blocks are usually ignored, but we can preserve them in AST
          node = AST::BlockNode.new(
            location: location,
            block_type: :comment
          )

          lines.each do |line|
            text_node = AST::TextNode.new(location: location, content: line)
            node.add_child(text_node)
          end
          @current_ast_node.add_child(node)
        when :olnum
          # Simple olnum block node - will be processed by OlnumProcessor
          node = AST::BlockNode.new(
            location: location,
            block_type: :olnum,
            args: args
          )
          # Store lines if any
          lines.each do |line|
            text_node = AST::TextNode.new(location: location, content: line)
            node.add_child(text_node)
          end
          @current_ast_node.add_child(node)
        when :footnote, :endnote
          # Footnote and endnote commands
          node = AST::FootnoteNode.new(
            location: location,
            id: args[0],
            content: lines&.join("\n"),
            footnote_type: name
          )
          # Parse inline elements in footnote content
          if lines && lines.any?
            lines.each do |line|
              inline_processor.parse_inline_elements(line, node)
            end
          end
          @current_ast_node.add_child(node)
        when :blankline, :noindent, :pagebreak, :firstlinenum, :tsize, :label, :printendnotes, :hr, :bpo, :parasep
          # Control commands without content or with special handling
          node = AST::BlockNode.new(
            location: location,
            block_type: name,
            args: args
          )
          # Store lines if any
          lines.each do |line|
            text_node = AST::TextNode.new(location: location, content: line)
            node.add_child(text_node)
          end
          @current_ast_node.add_child(node)
        when :beginchild, :endchild
          # Child nesting control
          node = AST::BlockNode.new(
            location: location,
            block_type: name
          )
          @current_ast_node.add_child(node)
        when :texequation
          # Math equations - use specialized block handling
          # Note: texequation is intentionally using BlockNode rather than CodeBlockNode
          # because math content doesn't need line numbers, syntax highlighting, or inline processing
          node = AST::BlockNode.new(
            location: location,
            block_type: :texequation,
            id: args && args[0],
            caption: args && args[1]
          )
          lines.each do |line|
            text_node = AST::TextNode.new(location: location, content: line)
            node.add_child(text_node)
          end
          @current_ast_node.add_child(node)
        else
          # Unknown block command - raise error with location info
          raise CompileError, "Unknown block command: //#{name}#{format_location_info(location)}"
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
        processed_caption = AST::CaptionNode.parse(
          caption,
          location: location,
          inline_processor: inline_processor
        )

        node = AST::HeadlineNode.new(location: location, level: level, label: label, caption: processed_caption)
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
        @current_location
      end

      # Force override current location - FOR TESTING ONLY
      # This method bypasses normal location tracking and should only be used in tests
      # @param location [Location] The location to force set
      def force_override_location!(location)
        @current_location = location
      end

      # Format location information for error messages
      def format_location_info(loc = nil)
        loc ||= @current_location
        return '' unless loc

        info = " at line #{loc.lineno}"
        info += " in #{loc.filename}" if loc.filename
        info
      end

      def add_child_to_current_node(node)
        @current_ast_node.add_child(node)
      end

      # Find appropriate parent node for a given headline level
      # This handles section nesting by traversing up the current node hierarchy
      def find_appropriate_parent_for_level(level)
        node = @current_ast_node

        # Traverse up to find a node at the appropriate level
        while node != @ast_root
          # If current node is a ColumnNode or HeadlineNode, check its level
          if node.respond_to?(:level) && node.level
            # If we find a node at same or higher level, go to its parent
            if node.level >= level
              node = node.parent || @ast_root
            else
              # Current node level is lower, this is the right parent
              break
            end
          else
            # Move up one level
            node = node.parent || @ast_root
          end
        end

        node
      end

      # Expose performance tracker for external access
      attr_reader :performance_tracker

      # Universal block content processing method for HTML Builder compatibility
      # This method processes structured content within block elements using the same
      # parsing logic as regular document processing, ensuring consistent behavior
      def process_structured_content(parent_node, lines)
        return unless lines && lines.any?

        # Create StringIO from lines to simulate file input for line processing
        content = lines.join("\n") + "\n"
        line_input = ReVIEW::LineInput.from_string(content)

        # Save current node context
        saved_current_node = @current_ast_node
        saved_location = @current_location

        # Set parent as current node for child processing
        @current_ast_node = parent_node

        # Process lines using the same logic as main document processing
        while line_input.next?
          # Create location that reflects position within the block
          @current_location = SnapshotLocation.new(@chapter&.basename || 'block', line_input.lineno)
          line_content = line_input.peek

          case line_content
          when /\A\s*\z/ # blank line
            line_input.gets # consume blank line but don't create node
          when /\A\s+\*\s/ # unordered list (must start with space)
            compile_ul_to_ast(line_input)
          when /\A\s+\d+\.\s/ # ordered list (must start with space)
            compile_ol_to_ast(line_input)
          when /\A\s+:\s/ # definition list (must start with space)
            compile_dl_to_ast(line_input)
          else
            # Regular paragraph content
            compile_paragraph_to_ast(line_input)
          end
        end

        # Restore context
        @current_ast_node = saved_current_node
        @current_location = saved_location
      end

      # Helper method to create and add block nodes with inline processing
      def create_and_add_block_node(block_type:, args: nil, lines: nil, caption: nil, **options)
        lines ||= []
        node = AST::BlockNode.new(
          location: location,
          block_type: block_type,
          args: args,
          caption: caption,
          **options
        )

        lines.each do |line|
          inline_processor.parse_inline_elements(line, node)
        end

        add_child_to_current_node(node)
        node
      end

      private

      def read_command(f)
        # Simplified implementation with proper arg parsing
        line = f.gets
        name = line.slice(/[a-z]+/).to_sym
        args = parse_args(line.sub(%r{\A//[a-z]+}, '').rstrip.chomp('{'), name)
        lines = block_open?(line) ? read_block(f) : []
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

      # Process inline elements within table cell content
      def process_table_line_inline_elements(line)
        return line unless line.include?('@<')

        # Create a temporary paragraph node to process inline elements
        temp_paragraph = AST::ParagraphNode.new(location: location)
        inline_processor.parse_inline_elements(line, temp_paragraph)

        # Convert back to text with processed inline elements
        render_children_to_text(temp_paragraph)
      end

      # Process noindent commands in the AST
      def process_noindent_commands
        return unless @ast_root

        require_relative('noindent_processor')
        processor = NoIndentProcessor.new
        processor.process(@ast_root)
      end

      # Process olnum commands in the AST
      def process_olnum_commands
        return unless @ast_root

        require_relative('olnum_processor')
        processor = OlnumProcessor.new
        processor.process(@ast_root)
      end
    end
  end
end
