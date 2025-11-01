# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'
require 'review/exception'
require 'review/loggable'
require 'review/lineinput'
require 'review/ast/inline_processor'
require 'review/ast/block_processor'
require 'review/ast/block_data'
require 'review/ast/compiler/block_context'
require 'review/ast/compiler/block_reader'
require 'review/snapshot_location'
require 'review/ast/list_processor'
require 'review/ast/footnote_node'
require 'review/ast/reference_resolver'
require 'review/ast/compiler/tsize_processor'
require 'review/ast/compiler/firstlinenum_processor'
require 'review/ast/compiler/noindent_processor'
require 'review/ast/compiler/olnum_processor'
require 'review/ast/compiler/list_structure_normalizer'
require 'review/ast/compiler/list_item_numbering_processor'
require 'review/ast/compiler/auto_id_processor'
require 'review/ast/headline_parser'

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
      MAX_HEADLINE_LEVEL = 6

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

        # Location tracking - initialize with default location
        @current_location = SnapshotLocation.new(nil, 0)

        # Processors for specialized AST handling
        @inline_processor = InlineProcessor.new(self)
        @block_processor = BlockProcessor.new(self)
        @list_processor = ListProcessor.new(self)

        @logger = ReVIEW.logger

        # Get config for debug output
        @config = {}

        # Error accumulation flag (similar to HTMLBuilder's Compiler)
        @compile_errors = false

        # Commands that preserve content as-is (matching ReVIEW::Compiler behavior)
        @non_parsed_commands = %i[embed texequation graph]
      end

      attr_reader :ast_root, :current_ast_node, :chapter, :inline_processor, :block_processor, :list_processor

      def compile_to_ast(chapter, reference_resolution: true)
        @chapter = chapter
        # Create AST root with appropriate location
        # For test compatibility, use a special calculation for line numbers
        f = LineInput.from_string(@chapter.content)

        @ast_root = AST::DocumentNode.new(
          location: SnapshotLocation.new(@chapter.basename, f.lineno + 1),
          chapter: @chapter
        )
        @current_ast_node = @ast_root

        build_ast_from_chapter

        # Resolve references after AST building but before post-processing
        # Skip if explicitly requested (e.g., during index building)
        if reference_resolution
          resolve_references
        end

        execute_post_processes

        # Check for accumulated errors (similar to HTMLBuilder's Compiler)
        if @compile_errors
          raise CompileError, "#{chapter.basename} cannot be compiled."
        end

        # Return the compiled AST
        @ast_root
      end

      def execute_post_processes
        # Post-process AST for tsize commands (must be before other processors)
        TsizeProcessor.process(@ast_root, chapter: @chapter, compiler: self)

        # Post-process AST for firstlinenum commands
        FirstLineNumProcessor.process(@ast_root, chapter: @chapter, compiler: self)

        # Post-process AST for noindent and olnum commands
        NoindentProcessor.process(@ast_root, chapter: @chapter, compiler: self)
        OlnumProcessor.process(@ast_root, chapter: @chapter, compiler: self)

        # Normalize list structures (process //beginchild and //endchild)
        ListStructureNormalizer.process(@ast_root, chapter: @chapter, compiler: self)

        # Assign item numbers to ordered list items
        ListItemNumberingProcessor.process(@ast_root, chapter: @chapter, compiler: self)

        # Generate auto_id for HeadlineNode (nonum/notoc/nodisp) and ColumnNode
        AutoIdProcessor.process(@ast_root, chapter: @chapter, compiler: self)
      end

      def build_ast_from_chapter
        f = LineInput.from_string(@chapter.content)

        # Build the complete AST structure
        while f.next?
          # Create a snapshot location that captures the current line number
          @current_location = SnapshotLocation.new(@chapter.basename, f.lineno + 1)
          line_content = f.peek
          case line_content
          when /\A\#@/
            f.gets # skip preprocessor directives
          when /\A=+[\[\s{]/
            compile_headline_to_ast(f.gets)
          when /\A\s*\z/ # rubocop:disable Lint/DuplicateBranch -- blank lines separate elements
            f.gets # consume blank line but don't create node
          when %r{\A//}
            compile_block_command_to_ast(f)
          when /\A\s+\*+\s/ # unordered list (must start with space, supports nesting with **)
            compile_ul_to_ast(f)
          when /\A\s+\d+\.\s/ # ordered list (must start with space)
            compile_ol_to_ast(f)
          when /\A\s*:\s/ # definition list (may start with optional space)
            compile_dl_to_ast(f)
          else
            compile_paragraph_to_ast(f)
          end
        end
      end

      def compile_headline_to_ast(line)
        parse_result = HeadlineParser.parse(line, location: location)
        return nil unless parse_result

        caption_node = build_caption_node(parse_result.caption, caption_location: location)
        current_node = find_appropriate_parent_for_level(parse_result.level)

        create_headline_node(parse_result, caption_node, current_node)
      end

      def build_caption_node(raw_caption_text, caption_location:)
        return nil if raw_caption_text.nil? || raw_caption_text.empty?

        caption_node = AST::CaptionNode.new(location: caption_location)

        begin
          with_temporary_location!(caption_location) do
            inline_processor.parse_inline_elements(raw_caption_text, caption_node)
          end
        rescue StandardError => e
          raise CompileError, "Error processing caption '#{caption_text}': #{e.message}#{caption_location.format_for_error}"
        end

        caption_node
      end

      def create_headline_node(parse_result, caption_node, current_node)
        if parse_result.column?
          create_column_node(parse_result, caption_node, current_node)
        elsif parse_result.closing_tag?
          handle_closing_tag(parse_result)
        else
          create_regular_headline(parse_result, caption_node, current_node)
        end
      end

      def create_column_node(parse_result, caption_node, current_node)
        node = AST::ColumnNode.new(
          location: location,
          level: parse_result.level,
          label: parse_result.label,
          caption_node: caption_node,
          column_type: :column,
          inline_processor: inline_processor
        )
        current_node.add_child(node)
        @current_ast_node = node
      end

      def handle_closing_tag(parse_result)
        open_tag = parse_result.closing_tag_name

        # Validate that we're closing the correct tag by checking current AST node
        if open_tag == 'column'
          unless @current_ast_node.is_a?(AST::ColumnNode)
            raise ReVIEW::ApplicationError, "column is not opened#{@current_location.format_for_error}"
          end
        else
          raise ReVIEW::ApplicationError, "Unknown closing tag: /#{open_tag}#{@current_location.format_for_error}"
        end

        @current_ast_node = @current_ast_node.parent || @ast_root
      end

      def create_regular_headline(parse_result, caption_node, current_node)
        node = AST::HeadlineNode.new(
          location: location,
          level: parse_result.level,
          label: parse_result.label,
          caption_node: caption_node,
          tag: parse_result.tag
        )
        current_node.add_child(node)
        @current_ast_node = @ast_root
      end

      def compile_paragraph_to_ast(f)
        raw_lines = []
        f.until_match(%r{\A//|\A\#@}) do |line|
          break if line.strip.empty?

          # Match ReVIEW::Compiler behavior: preserve tabs, strip other whitespace
          # Process: escape tabs -> strip -> restore tabs
          processed_line = line.sub(/^(\t+)\s*/) { |m| '<!ESCAPETAB!>' * m.size }.strip.gsub('<!ESCAPETAB!>', "\t")
          raw_lines.push(processed_line)
        end

        return if raw_lines.empty?

        # Create single paragraph node with multiple lines joined by \n
        # AST preserves line breaks; HTMLRenderer removes them for Builder compatibility
        node = AST::ParagraphNode.new(location: location)
        combined_text = raw_lines.join("\n") # Join lines with newline (AST preserves structure)
        inline_processor.parse_inline_elements(combined_text, node)
        @current_ast_node.add_child(node)
      end

      def compile_block_command_to_ast(f)
        block_data = read_block_command(f)
        block_processor.process_block_command(block_data)
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

      # Helper methods that need to be accessible from processors
      def location
        @current_location
      end

      # Force override current location - FOR TESTING ONLY
      # This method bypasses normal location tracking and should only be used in tests
      # @param location [SnapshotLocation] The location to force set
      def force_override_location!(location)
        @current_location = location
      end

      # Update current location based on file input position
      # @param file_input [LineInput] The file input object
      def update_current_location(file_input)
        @current_location = SnapshotLocation.new(@chapter.basename, file_input.lineno)
      end

      # Override error method to accumulate errors (similar to HTMLBuilder's Compiler)
      def error(msg, location: nil)
        @compile_errors = true
        super
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

      # Block-Scoped Compilation Support

      # Execute block processing in dedicated context
      # Maintain block start location information and perform AST construction with consistent location information
      #
      # @param block_data [BlockData] Block data to process
      # @yield [BlockContext] Block processing context
      # @return [Object] Processing result within block
      def with_block_context(block_data)
        context = BlockContext.new(block_data: block_data, compiler: self)

        yield(context)
      end

      # Temporarily override location information and execute block
      # Automatically restore original location information after block execution
      #
      # @param new_location [SnapshotLocation] Location information to set temporarily
      # @yield New location information is effective during block execution
      # @return [Object] Block execution result
      def with_temporary_location!(new_location)
        old_location = @current_location
        @current_location = new_location
        begin
          yield
        ensure
          @current_location = old_location
        end
      end

      # Temporarily override AST node and execute block
      # Automatically restore original AST node after block execution
      #
      # @param new_node [AST::Node] AST node to set temporarily
      # @yield New AST node is effective during block execution
      # @return [Object] Block execution result
      def with_temporary_ast_node!(new_node)
        old_node = @current_ast_node
        @current_ast_node = new_node
        begin
          yield
        ensure
          @current_ast_node = old_node
        end
      end

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
          when /\A\s+\*+\s/ # unordered list (must start with space, supports nesting with **)
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

      # IO reading dedicated method - nesting support and error handling
      def read_block_command(f, initial_line = nil)
        # Save location information at block start
        block_start_location = @current_location

        line = initial_line || f.gets
        unless line
          raise CompileError, "Unexpected end of file while reading block command#{@current_location.format_for_error}"
        end

        # Special handling for termination tags (processed in normal compilation flow)
        if line.start_with?('//}')
          raise CompileError, "Unexpected block terminator '//}' without opening block#{@current_location.format_for_error}"
        end

        # Extract command name
        command_match = line.match(%r{\A//([a-z]+)})
        unless command_match
          raise CompileError, "Invalid block command syntax: '#{line.strip}'#{@current_location.format_for_error}"
        end

        name = command_match[1].to_sym
        args = parse_args(line.sub(%r{\A//[a-z]+}, '').rstrip.chomp('{'), name)

        # Read block content (with nesting support)
        if block_open?(line)
          lines, nested_blocks = read_block_with_nesting(f, name, block_start_location)
        else
          lines = []
          nested_blocks = []
        end

        BlockData.new(
          name: name,
          args: args,
          lines: lines,
          nested_blocks: nested_blocks,
          location: block_start_location
        )
      rescue StandardError => e
        # Re-raise block reading errors with appropriate location information
        if e.is_a?(CompileError)
          raise e
        else
          raise CompileError, "Error reading block command: #{e.message}#{@current_location.format_for_error}"
        end
      end

      # Reading with nested block support - enhanced error handling
      def read_block_with_nesting(f, parent_command, block_start_location)
        reader = BlockReader.new(
          compiler: self,
          file_input: f,
          parent_command: parent_command,
          start_location: block_start_location,
          preserve_whitespace: preserve_whitespace?(parent_command)
        )
        reader.read
      end

      private

      def block_open?(line)
        line.rstrip.end_with?('{')
      end

      def preserve_whitespace?(command)
        @non_parsed_commands.include?(command)
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

      # Resolve references in the AST
      def resolve_references
        # Skip reference resolution in test environments or when chapter lacks book context
        # Chapter objects always have book method (from BookUnit/Chapter)
        return unless @chapter.book

        resolver = ReferenceResolver.new(@chapter)
        result = resolver.resolve_references(@ast_root)

        warn "Reference resolution: #{result[:resolved]} resolved, #{result[:failed]} failed" if result[:failed] > 0
      end
    end
  end
end
