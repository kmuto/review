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

        # State for tracking modifier commands like olnum
        @pending_olnum = nil

        # Processors for specialized AST handling - lazy initialization
        @inline_processor = nil
        @block_processor = nil
        @list_processor = nil

        @logger = ReVIEW.logger

        # Get config for debug output
        @config = builder&.instance_variable_get(:@config) || {}

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

      attr_reader :builder, :ast_root, :current_ast_node

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

        # If builder is provided, render AST to builder for compatibility
        if @builder
          render_ast_to_builder(@ast_root)
        end

        # Record performance statistics
        @performance_tracker.end_timing(:total_compilation_time)
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

        # Flush any remaining pending olnum at the end
        flush_pending_olnum_if_needed
      end

      # Render AST to builder for compatibility with existing tests
      def render_ast_to_builder(node) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
        case node
        when AST::DocumentNode
          node.children.each { |child| render_ast_to_builder(child) }
        when AST::HeadlineNode
          @builder.headline(node.level, node.label, node.caption_markup_text)
        when AST::ColumnNode
          @builder.column_begin(node.level, node.label, node.caption.to_text)
          node.children.each { |child| render_ast_to_builder(child) }
          @builder.column_end(node.level)
        when AST::ParagraphNode
          lines = node.children.map do |child|
            render_ast_node_to_text(child)
          end
          @builder.paragraph(lines)
        when AST::CodeBlockNode
          # Use original_lines for builders that don't need inline processing
          # Use processed_lines for builders that need inline element processing
          lines_to_use = if @builder && @builder.class.name.include?('IDGXML')
                           # IDGXML builder needs inline processing
                           node.processed_lines.map { |line| process_table_line_inline_elements(line) }
                         else
                           # Most builders can use original text
                           node.original_lines
                         end

          # Handle different code block types based on their requirements
          if node.id && !node.id.empty?
            # For blocks with ID (list, listnum, source)
            if node.line_numbers
              @builder.listnum(lines_to_use, node.id, node.caption_markup_text || '', node.lang)
            else
              @builder.list(lines_to_use, node.id, node.caption_markup_text || '', node.lang)
            end
          elsif node.line_numbers
            # For blocks without ID (emlist, emlistnum, cmd)
            @builder.emlistnum(lines_to_use, node.caption_markup_text || '', node.lang)
          else
            # emlist (including cmd which is just emlist with shell lang)
            @builder.emlist(lines_to_use, node.caption_markup_text || '', node.lang)
          end
        when AST::TableNode
          # Convert TableNode structure to Builder format
          # Builder expects all lines including headers, separator, and rows
          lines = []

          # Process header rows
          header_lines = node.header_rows.map do |header_row|
            # Convert TableRowNode to tab-separated string
            header_row.children.map do |cell|
              # Render cell content to text with inline processing
              render_children_to_text(cell)
            end.join("\t")
          end

          # Process body rows
          body_lines = node.body_rows.map do |body_row|
            # Convert TableRowNode to tab-separated string
            body_row.children.map do |cell|
              # Render cell content to text with inline processing
              render_children_to_text(cell)
            end.join("\t")
          end

          # Build lines array with headers, separator if needed, and body
          if header_lines.any?
            lines.concat(header_lines)
            lines << '------------' # Add separator line
          end
          lines.concat(body_lines)

          if lines.any?
            # Handle different table types
            case node.table_type
            when :emtable
              @builder.emtable(lines, node.caption_markup_text || '')
            when :imgtable
              @builder.imgtable(lines, node.id || '', node.caption_markup_text || '', node.metric)
            else
              # Regular table with ID
              @builder.table(lines, node.id || '', node.caption_markup_text || '')
            end
          end
        when AST::ImageNode
          @builder.image([], node.id || '', node.caption_markup_text || '')
        when AST::ListNode
          render_list_to_builder(node)
        when AST::EmbedNode
          render_embed_to_builder(node)
        when AST::BlockNode
          render_block_to_builder(node)
        when AST::MinicolumnNode
          render_minicolumn_to_builder(node)
        end
      end

      def render_ast_node_to_text(node)
        case node
        when AST::TextNode
          # Process inline elements in text content
          process_table_line_inline_elements(node.content)
        when AST::InlineNode
          content = render_children_to_text(node)
          case node.inline_type
          when 'fn'
            arg = node.respond_to?(:args) && node.args ? node.args.first : content
            @builder.inline_fn(arg)
          when 'kw'
            # For kw, reconstruct the argument format that builder expects
            kw_arg = if node.respond_to?(:args) && node.args && node.args.length >= 2
                       "#{node.args[0]}, #{node.args[1]}"
                     else
                       content
                     end
            @builder.inline_kw(kw_arg)
          when 'href'
            arg = node.respond_to?(:args) && node.args ? node.args.first : ''
            @builder.inline_href(arg)
          else
            @builder.__send__("inline_#{node.inline_type}", content)
          end
        when AST::EmbedNode
          if node.embed_type == :inline
            node.arg || ''
          else
            ''
          end
        else
          render_children_to_text(node)
        end
      end

      def render_children_to_text(node)
        return '' unless node.children

        node.children.map { |child| render_ast_node_to_text(child) }.join
      end

      def render_list_to_builder(node)
        case node.list_type
        when :ul
          @builder.ul_begin
          node.children.each do |item|
            @builder.ul_item_begin([render_children_to_text(item)])
            @builder.ul_item_end
          end
          @builder.ul_end
        when :ol
          @builder.ol_begin
          node.children.each_with_index do |item, index|
            @builder.ol_item([render_children_to_text(item)], index + 1)
          end
          @builder.ol_end
        when :dl
          @builder.dl_begin
          node.children.each do |item|
            next unless item.respond_to?(:children) && item.children.any?

            @builder.dt(render_ast_node_to_text(item.children[0]))
            if item.children.size > 1
              @builder.dd([item.children[1..-1].map { |child| render_ast_node_to_text(child) }.join])
            end
          end
          @builder.dl_end
        end
      end

      def render_embed_to_builder(node)
        case node.embed_type
        when :inline
          # Inline embeds are handled in render_ast_node_to_text
        when :block
          if node.lines && node.lines.any?
            # Use the embed method with arg filter
            @builder.embed(node.lines, node.arg)
          end
        when :raw
          if node.lines && node.lines.any?
            # For raw blocks, use the raw method
            @builder.raw(node.arg, node.lines)
          end
        end
      end

      def render_block_to_builder(node)
        case node.block_type
        when :quote
          quote_lines = node.children.map { |child| render_ast_node_to_text(child) }
          @builder.quote(quote_lines)
        when :read
          # For read blocks, output the content directly
          read_lines = node.children.map { |child| render_ast_node_to_text(child) }
          @builder.nofunc_text(read_lines.join("\n")) if read_lines.any?
        end
      end

      def render_minicolumn_to_builder(node)
        # Extract text content from children
        lines = node.children.map { |child| render_ast_node_to_text(child) }

        # Call appropriate builder method based on minicolumn type
        case node.minicolumn_type
        when :note
          @builder.note(lines, node.caption_markup_text)
        when :memo
          @builder.memo(lines, node.caption_markup_text)
        when :tip
          @builder.tip(lines, node.caption_markup_text)
        when :info
          @builder.info(lines, node.caption_markup_text)
        when :warning
          @builder.warning(lines, node.caption_markup_text)
        when :important
          @builder.important(lines, node.caption_markup_text)
        when :caution
          @builder.caution(lines, node.caption_markup_text)
        when :notice
          @builder.notice(lines, node.caption_markup_text)
        end
      end

      # AST-specific compilation methods
      def compile_headline_to_ast(line)
        # Parse headline using same logic as compile_headline
        # Handle both new syntax: = Caption{label} and old syntax: ={label} Caption
        m = /\A(=+)(?:\[(.+?)\])?(?:\{(.+?)\})?(.*?)(?:\{(.+?)\})?\s*\z/.match(line)
        level = m[1].size
        if level > 6 # MAX_HEADLINE_LEVEL
          raise CompileError, 'Invalid header: max headline level is 6'
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
        # If there's a pending olnum and we're processing a paragraph (not a list),
        # we need to add the olnum as a standalone block first
        flush_pending_olnum_if_needed

        raw_lines = []
        f.until_match(%r{\A//|\A\#@}) do |line|
          break if line.strip.empty?

          raw_lines.push(line.sub(/^(\t+)\s*/) { |m| '<!ESCAPETAB!>' * m.size }.strip.gsub('<!ESCAPETAB!>', "\t"))
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
        name, args, lines = read_command(f)

        # Only flush if this is not an olnum command
        flush_pending_olnum_if_needed unless name == :olnum

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
          # Special handling for olnum - store for next ordered list
          @pending_olnum = {
            location: location,
            args: args,
            lines: lines
          }
          # Don't add olnum as a standalone node - it will be applied to the next ordered list
        when :blankline, :noindent, :pagebreak, :firstlinenum, :tsize, :footnote, :endnote, :label, :printendnotes, :hr, :bpo, :parasep
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
          # Unknown block command - raise error instead of creating generic node
          raise CompileError, "Unknown block command: //#{name}"
        end
      end

      def ast_result
        @ast_root
      end

      # Compile unordered list to AST (delegates to list processor)
      def compile_ul_to_ast(f)
        # Flush any pending olnum since this is not an ordered list
        flush_pending_olnum_if_needed
        list_processor.process_unordered_list(f)
      end

      # Compile ordered list to AST (delegates to list processor)
      def compile_ol_to_ast(f)
        # Pass pending olnum information to list processor
        olnum_info = @pending_olnum
        @pending_olnum = nil # Clear after use

        list_processor.process_ordered_list(f, olnum_info: olnum_info)
      end

      # Compile definition list to AST (delegates to list processor)
      def compile_dl_to_ast(f)
        # Flush any pending olnum since this is not an ordered list
        flush_pending_olnum_if_needed
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
        @current_location || @builder.location
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

      # Flush pending olnum if needed (when non-list content follows olnum)
      def flush_pending_olnum_if_needed
        return unless @pending_olnum

        # Create standalone olnum block node
        node = AST::BlockNode.new(
          location: @pending_olnum[:location],
          block_type: :olnum,
          args: @pending_olnum[:args]
        )

        # Store lines if any
        @pending_olnum[:lines].each do |line|
          text_node = AST::TextNode.new(location: @pending_olnum[:location], content: line)
          node.add_child(text_node)
        end

        @current_ast_node.add_child(node)
        @pending_olnum = nil
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
    end
  end
end
