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
require 'review/ast/block_context'
require 'review/snapshot_location'
require 'review/ast/list_processor'
require 'review/ast/footnote_node'
require 'review/ast/reference_resolver'
require 'review/ast/tsize_processor'
require 'review/ast/noindent_processor'
require 'review/ast/olnum_processor'
require 'review/ast/list_structure_normalizer'
require 'review/ast/list_item_numbering_processor'

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

        # Processors for specialized AST handling - lazy initialization
        @inline_processor = nil
        @block_processor = nil
        @list_processor = nil

        # Block-scoped compilation support
        @block_context_stack = []

        # Tagged section tracking (for column tags etc.)
        @tagged_section = []

        @logger = ReVIEW.logger

        # Get config for debug output
        @config = {}

        # Error accumulation flag (similar to HTMLBuilder's Compiler)
        @compile_errors = false
      end

      attr_reader :ast_root, :current_ast_node, :chapter

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

        build_ast

        # Resolve references after AST building but before post-processing
        # Skip if explicitly requested (e.g., during index building)
        if reference_resolution
          resolve_references
        end

        # Post-process AST for tsize commands (must be before other processors)
        # Determine target format for tsize processing
        target_format = determine_target_format_for_tsize
        TsizeProcessor.process(@ast_root, target_format: target_format)

        # Post-process AST for noindent and olnum commands
        NoindentProcessor.process(@ast_root)
        OlnumProcessor.process(@ast_root)

        # Normalize list structures (process //beginchild and //endchild)
        ListStructureNormalizer.process(@ast_root)

        # Assign item numbers to ordered list items
        ListItemNumberingProcessor.process(@ast_root)

        # Check for accumulated errors (similar to HTMLBuilder's Compiler)
        if @compile_errors
          raise CompileError, "#{chapter.basename} cannot be compiled."
        end

        # Return the compiled AST
        @ast_root
      end

      def build_ast
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
        # Parse headline more carefully to handle inline markup in captions
        # First, extract level and optional tag
        level_match = /\A(=+)(?:\[(.+?)\])?/.match(line)
        return nil unless level_match

        level = level_match[1].size
        if level > MAX_HEADLINE_LEVEL
          raise CompileError, "Invalid header: max headline level is 6#{format_location_info}"
        end

        tag = level_match[2]
        remaining = line[level_match.end(0)..-1].strip

        # Now handle label and caption extraction
        label = nil
        caption = nil

        # Check for old syntax: {label} Caption
        if remaining =~ /\A\{([^}]+)\}\s*(.+)/
          label = $1
          caption = $2.strip
        # Check for new syntax: Caption{label} - but only if the last {...} is not part of inline markup
        elsif remaining.match(/\A(.+?)\{([^}]+)\}\s*\z/) && !$1.match?(/@<[^>]+>\s*\z/)
          caption = $1.strip
          label = $2
        else
          # No label, or label is part of inline markup - treat everything as caption
          caption = remaining
        end

        caption_text = caption
        caption_node = nil

        if caption_text && !caption_text.empty?
          caption_node = AST::CaptionNode.new(location: location)

          begin
            with_temporary_location!(location) do
              inline_processor.parse_inline_elements(caption_text, caption_node)
            end
          rescue StandardError => e
            raise CompileError, "Error processing caption '#{caption_text}': #{e.message}#{format_location_info(location)}"
          end
        end

        # Before creating new section, handle section nesting
        # Find appropriate parent level for this headline/section
        current_node = find_appropriate_parent_for_level(level)
        # Handle tagged sections
        if tag == 'column'
          node = AST::ColumnNode.new(
            location: location,
            level: level,
            label: label,
            caption: caption_text,
            caption_node: caption_node,
            column_type: 'column',
            inline_processor: inline_processor
          )
          current_node.add_child(node)
          # Set column as current node so subsequent content becomes its children
          @current_ast_node = node
          # Track column opening for error checking
          @tagged_section.push(['column', level])
        elsif tag&.start_with?('/')
          # Closing tag (e.g., /column, /column_dummy)
          open_tag = tag[1..-1] # Remove leading '/'
          prev_tag_info = @tagged_section.pop
          if prev_tag_info.nil? || prev_tag_info.first != open_tag
            raise ReVIEW::ApplicationError, "#{open_tag} is not opened#{format_location_info}"
          end

          # Column end tag - reset current node to parent (exiting column context)
          @current_ast_node = @current_ast_node.parent || @ast_root
          # Don't create any node for column end tag
        else
          # Regular headline or headline with options (nonum, notoc, nodisp)
          node = AST::HeadlineNode.new(
            location: location,
            level: level,
            label: label,
            caption: caption_text,
            caption_node: caption_node,
            tag: tag
          )
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
        @block_context_stack.push(context)

        begin
          yield(context)
        ensure
          @block_context_stack.pop
        end
      end

      # Get current block context
      # Returns the innermost context in nested block processing
      #
      # @return [BlockContext, nil] Current block context
      def current_block_context
        @block_context_stack.last
      end

      # Get current block start position
      # Returns start position within block context, current position outside
      #
      # @return [Location] Location information
      def current_block_location
        current_block_context&.start_location || @current_location
      end

      # Determine if within block context
      #
      # @return [Boolean] true if within block context
      def in_block_context?
        !@block_context_stack.empty?
      end

      # Temporarily override location information and execute block
      # Automatically restore original location information after block execution
      #
      # @param new_location [Location] Location information to set temporarily
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
          raise CompileError, "Unexpected end of file while reading block command#{format_location_info}"
        end

        # Special handling for termination tags (processed in normal compilation flow)
        if line.start_with?('//}')
          raise CompileError, "Unexpected block terminator '//}' without opening block#{format_location_info}"
        end

        # Extract command name
        command_match = line.match(%r{\A//([a-z]+)})
        unless command_match
          raise CompileError, "Invalid block command syntax: '#{line.strip}'#{format_location_info}"
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
          raise CompileError, "Error reading block command: #{e.message}#{format_location_info}"
        end
      end

      # Reading with nested block support - enhanced error handling
      def read_block_with_nesting(f, parent_command, block_start_location)
        lines = []
        nested_blocks = []
        block_depth = 1 # Starting block count
        start_location = block_start_location

        while f.next?
          line = f.gets
          unless line
            raise CompileError, "Unexpected end of file in block //#{parent_command} started#{format_location_info(start_location)}"
          end

          # Update location information
          @current_location = SnapshotLocation.new(@chapter.basename, f.lineno)

          # Detect termination tag
          if line.start_with?('//}')
            block_depth -= 1
            if block_depth == 0
              break # Reached corresponding termination tag
            else
              # Nested termination tag - treat as content
              lines << line.chomp
            end
          # Detect nested block commands
          elsif line.match?(%r{\A//[a-z]+})
            # Recursively read nested blocks
            begin
              nested_block_data = read_block_command(f, line)
              nested_blocks << nested_block_data
            rescue CompileError => e
              # Add parent context information to nested block errors
              raise CompileError, "#{e.message} (in nested block within //#{parent_command})"
            end
          # Skip preprocessor directives
          elsif /\A\#@/.match?(line)
            next
          else
            # Regular content line
            lines << line.chomp
          end
        end

        # Check if block is properly closed
        if block_depth > 0
          raise CompileError, "Unclosed block //#{parent_command} started#{format_location_info(start_location)}"
        end

        [lines, nested_blocks]
      end

      def block_open?(line)
        line.rstrip.end_with?('{')
      end

      private

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

      # Resolve references in the AST
      def resolve_references
        # Skip reference resolution in test environments or when chapter lacks book context
        # Chapter objects always have book method (from BookUnit/Chapter)
        return unless @chapter.book

        resolver = ReferenceResolver.new(@chapter)
        result = resolver.resolve_references(@ast_root)

        if result[:failed] > 0
          warn "Reference resolution: #{result[:resolved]} resolved, #{result[:failed]} failed"
        else
          debug("Reference resolution: #{result[:resolved]} references resolved successfully")
        end
      end

      # Determine target format for tsize processing
      # This helps TsizeProcessor decide which tsize commands to apply
      # based on |builder| target specification
      def determine_target_format_for_tsize
        # Try to infer from book config
        return nil unless @chapter.book&.config

        # Check if builder is specified in config
        builder = @chapter.book.config['builder']
        return builder if builder

        # If builder is not explicitly set, return nil
        # This causes TsizeProcessor to apply all tsize commands (no filtering)
        # which maintains backward compatibility
        nil
      end
    end
  end
end
