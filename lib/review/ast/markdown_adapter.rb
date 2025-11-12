# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'
require 'review/snapshot_location'
require 'review/exception'
require_relative 'markdown_html_node'
require_relative 'inline_tokenizer'

module ReVIEW
  module AST
    # MarkdownAdapter - Adapter to convert Markly AST to Re:VIEW AST
    #
    # This class walks the Markly AST and creates corresponding
    # Re:VIEW AST nodes.
    class MarkdownAdapter
      # ContextStack manages hierarchical context for AST node construction.
      # It provides exception-safe context switching with automatic cleanup.
      class ContextStack
        def initialize(initial_context)
          @stack = [initial_context]
        end

        def current
          @stack.last
        end

        def push(node)
          @stack.push(node)
        end

        def pop
          raise ReVIEW::CompileError, 'Cannot pop initial context from stack' if @stack.length <= 1

          @stack.pop
        end

        def with_context(node)
          push(node)
          yield
        ensure
          pop
        end

        def depth
          @stack.length
        end

        def validate!
          if @stack.any?(&:nil?)
            raise ReVIEW::CompileError, 'Context corruption: nil found in stack'
          end
        end

        def empty?
          @stack.length <= 1
        end

        def find_all(klass)
          @stack.find_all { |node| node.is_a?(klass) }
        end

        def any?(klass)
          @stack.any?(klass)
        end
      end

      # Placeholder for Re:VIEW inline notation marker (@<)
      # Used to restore notation from MarkdownCompiler's preprocessing
      REVIEW_NOTATION_PLACEHOLDER = '@@REVIEW_AT_LT@@'

      def initialize(compiler)
        @compiler = compiler
        @context = nil # Will be initialized in convert()

        # Initialize InlineTokenizer for processing Re:VIEW notation
        @inline_tokenizer = InlineTokenizer.new
      end

      # Convert Markly document to Re:VIEW AST
      #
      # @param markly_doc [Markly::Node] Markly document root
      # @param ast_root [DocumentNode] Re:VIEW AST root
      # @param chapter [ReVIEW::Book::Chapter] Chapter context (required)
      def convert(markly_doc, ast_root, chapter)
        @ast_root = ast_root
        @chapter = chapter

        # Initialize context stack with document root
        @context = ContextStack.new(ast_root)

        begin
          # Walk the Markly AST
          walk_node(markly_doc)

          # Close any remaining open columns at the end of the document
          close_all_columns

          # Validate final state
          validate_final_state!
        rescue ReVIEW::CompileError
          raise
        rescue StandardError => e
          raise ReVIEW::CompileError, "Markdown conversion failed: #{e.message}\n#{e.backtrace.join("\n")}"
        end
      end

      private

      # Recursively walk Markly nodes
      def walk_node(cm_node)
        # Process based on node type
        case cm_node.type
        when :document
          # Process children
          process_children(cm_node)

        when :header
          process_heading(cm_node)

        when :paragraph
          process_paragraph(cm_node)

        when :list
          process_list(cm_node)

        when :list_item
          process_list_item(cm_node)

        when :code_block
          process_code_block(cm_node)

        when :blockquote
          process_blockquote(cm_node)

        when :table
          process_table(cm_node)

        when :table_row
          process_table_row(cm_node)

        when :table_header
          process_table_header(cm_node)

        when :table_cell
          process_table_cell(cm_node)

        when :html_block, :html
          process_html_block(cm_node)

        when :hrule
          process_thematic_break(cm_node)

        when :footnote_definition
          process_footnote_definition(cm_node)

        else # rubocop:disable Style/EmptyElse
          # For inline elements and other types, delegate to inline processing
          # This includes :text, :strong, :emph, :code, :link, :image, etc.
          nil # Inline elements are processed within their parent context
        end
      end

      # Process children of a node
      def process_children(cm_node)
        cm_node.each do |child|
          walk_node(child)
        end
      end

      # Process heading node
      def process_heading(cm_node)
        level = cm_node.header_level

        # Extract text content to check for column marker
        heading_text = extract_text(cm_node)

        # Check if this is a column start marker: ### [column] Title or ### [column]
        if heading_text =~ /\A\s*\[column\](.*)/
          title = $1.strip
          title = nil if title.empty?

          # Start a column with heading-based syntax
          start_column_from_heading(cm_node, title, level)
        else
          # Auto-close columns if we encounter a heading at the same or higher level
          auto_close_columns_for_heading(level)

          # Regular heading processing
          # Create caption node with inline elements
          caption_node = CaptionNode.new(
            location: current_location(cm_node)
          )
          process_inline_content(cm_node, caption_node)

          # Create headline node
          headline = HeadlineNode.new(
            location: current_location(cm_node),
            level: level,
            label: nil, # Markdown doesn't have explicit labels
            caption_node: caption_node
          )

          add_node_to_current_context(headline)
        end
      end

      # Process paragraph node
      def process_paragraph(cm_node)
        # Check if this paragraph contains only an image
        if standalone_image_paragraph?(cm_node)
          process_standalone_image(cm_node)
          return
        end

        # Check if this is an attribute block for the previous table
        para_text = extract_text(cm_node).strip
        # Pattern: {#id caption="..."}
        attrs = parse_attribute_block(para_text)

        # Check if this is an attribute block for the previous table
        if attrs && @context.current.children.last.is_a?(TableNode)
          # Apply attributes to the last table
          last_table_node = @context.current.children.last
          table_id = attrs[:id]
          caption_text = attrs[:caption]

          # Build caption node if caption text is provided
          caption_node = nil
          if caption_text && !caption_text.empty?
            caption_node = CaptionNode.new(location: current_location(cm_node))
            caption_node.add_child(TextNode.new(
                                     location: current_location(cm_node),
                                     content: caption_text
                                   ))
          end

          # Update table attributes
          last_table_node.update_attributes(id: table_id, caption_node: caption_node)

          return # Don't add this paragraph as a regular node
        end

        # Regular paragraph processing
        para = ParagraphNode.new(
          location: current_location(cm_node)
        )

        # Process inline content
        process_inline_content(cm_node, para)

        add_node_to_current_context(para)
      end

      # Process list node
      def process_list(cm_node)
        list_node = ListNode.new(
          location: current_location(cm_node),
          list_type: cm_node.list_type == :ordered_list ? :ol : :ul,
          start_number: cm_node.list_type == :ordered_list ? cm_node.list_start : nil
        )

        add_node_to_current_context(list_node)

        # Use unified context management with exception safety
        @context.with_context(list_node) do
          # Process list items
          process_children(cm_node)
        end
      end

      # Process list item node
      def process_list_item(cm_node)
        item = ListItemNode.new(
          location: current_location(cm_node)
        )

        add_node_to_current_context(item)

        # Use unified context management with exception safety
        @context.with_context(item) do
          cm_node.each_with_index do |child, idx|
            if child.type == :paragraph && idx == 0
              # For the first paragraph in a list item, process inline content directly
              process_inline_content(child, item)
            else
              # For other blocks, process normally
              walk_node(child)
            end
          end
        end
      end

      # Process code block node
      def process_code_block(cm_node)
        code_info = cm_node.fence_info || ''

        # Parse language and attributes
        # Pattern: ruby {#id caption="..."}
        lang = nil
        attrs = nil

        if code_info =~ /\A(\S+)\s+(.+)\z/
          lang = ::Regexp.last_match(1)
          attr_text = ::Regexp.last_match(2)
          attrs = parse_attribute_block(attr_text)
        else
          lang = code_info.strip
          lang = nil if lang.empty?
        end

        # Extract ID and caption from attributes
        code_id = attrs&.[](:id)
        caption_text = attrs&.[](:caption)

        # Create caption node if caption text exists
        caption_node = if caption_text && !caption_text.empty?
                         node = CaptionNode.new(location: current_location(cm_node))
                         node.add_child(TextNode.new(
                                          location: current_location(cm_node),
                                          content: caption_text
                                        ))
                         node
                       end

        # Use :list type if ID is present (numbered list), otherwise :emlist
        code_type = code_id ? :list : :emlist

        # Restore Re:VIEW notation markers in code block content
        code_content = cm_node.string_content
        code_content = code_content.gsub(REVIEW_NOTATION_PLACEHOLDER, '@<')

        code_block = CodeBlockNode.new(
          location: current_location(cm_node),
          id: code_id,
          lang: lang,
          code_type: code_type,
          caption_node: caption_node,
          original_text: code_content
        )

        # Add code lines
        code_content.each_line.with_index do |line, idx|
          line_node = CodeLineNode.new(
            location: current_location(cm_node, line_offset: idx),
            original_text: line.chomp
          )
          line_node.add_child(TextNode.new(
                                location: current_location(cm_node, line_offset: idx),
                                content: line.chomp
                              ))
          code_block.add_child(line_node)
        end

        add_node_to_current_context(code_block)
      end

      # Process blockquote node
      def process_blockquote(cm_node)
        quote_node = BlockNode.new(
          location: current_location(cm_node),
          block_type: :quote
        )

        add_node_to_current_context(quote_node)

        # Use unified context management with exception safety
        @context.with_context(quote_node) do
          process_children(cm_node)
        end
      end

      # Process table node (GFM extension)
      def process_table(cm_node)
        table_node = TableNode.new(
          location: current_location(cm_node)
        )

        add_node_to_current_context(table_node)

        # Use unified context management with exception safety
        @context.with_context(table_node) do
          process_children(cm_node)
        end

        # Check if the last row contains only attribute block
        # This happens when Markly includes the attribute line as part of the table
        if table_node.body_rows.any?
          last_row = table_node.body_rows.last
          # Check if the last row has only one cell with attribute block
          if last_row.children.length >= 1
            first_cell = last_row.children.first
            # Extract text from all children of the cell
            cell_text = first_cell.children.map do |child|
              child.is_a?(TextNode) ? child.content : ''
            end.join.strip

            attrs = parse_attribute_block(cell_text)
            if attrs
              # Remove the last row from children (body_rows is a filtered view)
              table_node.children.delete(last_row)

              # Apply attributes to the table
              table_id = attrs[:id]
              caption_text = attrs[:caption]

              # Build caption node if caption text is provided
              caption_node = nil
              if caption_text && !caption_text.empty?
                caption_node = CaptionNode.new(location: current_location(cm_node))
                caption_node.add_child(TextNode.new(
                                         location: current_location(cm_node),
                                         content: caption_text
                                       ))
              end

              # Update table attributes
              table_node.update_attributes(id: table_id, caption_node: caption_node)

              # No need to track this table for next paragraph
              return
            end
          end
        end
      end

      # Process table row node
      def process_table_row(cm_node)
        row_node = TableRowNode.new(
          location: current_location(cm_node),
          row_type: :body
        )

        @context.current.add_body_row(row_node)

        # Process cells
        @context.with_context(row_node) do
          process_children(cm_node)
        end
      end

      # Process table header node
      def process_table_header(cm_node)
        row_node = TableRowNode.new(
          location: current_location(cm_node),
          row_type: :header
        )

        @context.current.add_header_row(row_node)

        # Process cells
        @context.with_context(row_node) do
          process_children(cm_node)
        end
      end

      # Process table cell node
      def process_table_cell(cm_node)
        cell_type = if @context.current.is_a?(TableRowNode) && @context.current.row_type == :header
                      :th
                    else
                      :td
                    end

        cell_node = TableCellNode.new(
          location: current_location(cm_node),
          cell_type: cell_type
        )

        # Process cell content
        process_inline_content(cm_node, cell_node)

        add_node_to_current_context(cell_node)
      end

      # Process HTML block
      def process_html_block(cm_node)
        html_content = cm_node.string_content.strip

        # Create MarkdownHtmlNode to analyze HTML content
        html_node = MarkdownHtmlNode.new(
          location: current_location(cm_node),
          html_content: html_content,
          html_type: detect_html_type(html_content)
        )

        # Check if this is a column marker
        if html_node.column_end?
          end_column(html_node)
        else
          # Regular HTML content - add to current context
          embed_node = EmbedNode.new(
            location: current_location(cm_node),
            embed_type: :html,
            content: html_content
          )
          add_node_to_current_context(embed_node)
        end
      end

      # Process thematic break (horizontal rule)
      def process_thematic_break(cm_node)
        hr_node = BlockNode.new(
          location: current_location(cm_node),
          block_type: :hr
        )

        add_node_to_current_context(hr_node)
      end

      # Process inline content within a node
      def process_inline_content(cm_node, parent_node)
        cm_node.each do |child|
          process_inline_node(child, parent_node)
        end
      end

      # Process individual inline node
      def process_inline_node(cm_node, parent_node)
        case cm_node.type
        when :text
          text = cm_node.string_content

          # Restore Re:VIEW notation markers (@<) from placeholders
          text = text.gsub(REVIEW_NOTATION_PLACEHOLDER, '@<')

          # Process Re:VIEW inline notation
          # Use InlineTokenizer to properly parse @<xxx>{id} with escape sequences
          location = current_location(cm_node)

          begin
            # Tokenize text for Re:VIEW inline notation
            tokens = @inline_tokenizer.tokenize(text, location: location)

            # Process each token
            tokens.each do |token|
              case token.type
              when :text
                # Text token: create TextNode
                parent_node.add_child(TextNode.new(location: location, content: token.content))

              when :inline
                # InlineToken: Re:VIEW inline notation @<xxx>{id}
                ref_type = token.command.to_sym
                ref_id = token.content

                # Create ReferenceNode
                reference_node = ReferenceNode.new(ref_id, nil, location: location)

                # Create InlineNode with reference type
                inline_node = InlineNode.new(location: location, inline_type: ref_type, args: [ref_id])
                inline_node.add_child(reference_node)

                parent_node.add_child(inline_node)
              end
            end
          rescue InlineTokenizeError => e
            # If tokenization fails, add error message as comment and add original text
            # This allows the document to continue processing
            warn("Failed to parse inline notation: #{e.message}")
            parent_node.add_child(TextNode.new(location: location, content: text))
          end

        when :strong
          inline_node = InlineNode.new(location: current_location(cm_node), inline_type: :b, args: [extract_text(cm_node)])
          process_inline_content(cm_node, inline_node)
          parent_node.add_child(inline_node)

        when :emph
          inline_node = InlineNode.new(location: current_location(cm_node), inline_type: :i, args: [extract_text(cm_node)])
          process_inline_content(cm_node, inline_node)
          parent_node.add_child(inline_node)

        when :code
          # Restore Re:VIEW notation markers in inline code
          code_content = cm_node.string_content
          code_content = code_content.gsub(REVIEW_NOTATION_PLACEHOLDER, '@<')

          inline_node = InlineNode.new(location: current_location(cm_node), inline_type: :code, args: [code_content])
          inline_node.add_child(TextNode.new(location: current_location(cm_node), content: code_content))
          parent_node.add_child(inline_node)

        when :link
          # Create href inline node
          inline_node = InlineNode.new(location: current_location(cm_node), inline_type: :href, args: [cm_node.url, extract_text(cm_node)])
          process_inline_content(cm_node, inline_node)
          parent_node.add_child(inline_node)

        when :image
          # Create icon inline node (Re:VIEW's image inline)
          inline_node = InlineNode.new(location: current_location(cm_node), inline_type: :icon, args: [cm_node.url])
          parent_node.add_child(inline_node)

        when :strikethrough
          # GFM extension
          inline_node = InlineNode.new(location: current_location(cm_node), inline_type: :del, args: [extract_text(cm_node)])
          process_inline_content(cm_node, inline_node)
          parent_node.add_child(inline_node)

        when :softbreak
          # Soft line break - convert to space
          parent_node.add_child(TextNode.new(location: current_location(cm_node), content: ' '))

        when :linebreak
          # Hard line break - preserve as newline
          parent_node.add_child(TextNode.new(location: current_location(cm_node), content: "\n"))

        when :footnote_reference
          # Footnote reference [^id] parsed by Markly
          # Get the actual footnote ID from the parent footnote definition
          footnote_id = if cm_node.respond_to?(:parent_footnote_def) && cm_node.parent_footnote_def
                          cm_node.parent_footnote_def.string_content
                        else
                          cm_node.string_content # Fallback to reference number
                        end

          # Create ReferenceNode
          reference_node = ReferenceNode.new(footnote_id, nil, location: current_location(cm_node))

          # Create InlineNode with fn type
          inline_node = InlineNode.new(location: current_location(cm_node), inline_type: :fn, args: [footnote_id])
          inline_node.add_child(reference_node)

          parent_node.add_child(inline_node)

        when :html_inline
          # Inline HTML - store as text for now
          parent_node.add_child(TextNode.new(location: current_location(cm_node), content: cm_node.string_content))

        else
          # Process any children
          process_inline_content(cm_node, parent_node)
        end
      end

      # Extract text content from a node
      def extract_text(cm_node)
        text = ''
        cm_node.each do |child|
          text += case child.type
                  when :text, :code
                    child.string_content
                  else
                    extract_text(child)
                  end
        end
        text
      end

      # Create location for current node
      def current_location(cm_node, line_offset: 0)
        # Try to use source position if available
        line = if cm_node.respond_to?(:source_position) && cm_node.source_position
                 cm_node.source_position[:start_line] + line_offset
               else
                 1 + line_offset # Default to line 1 if source position not available
               end

        SnapshotLocation.new(@chapter.basename, line)
      end

      # Detect HTML type from content
      def detect_html_type(html_content)
        if html_content.strip.start_with?('<!--') && html_content.strip.end_with?('-->')
          :comment
        elsif html_content.strip.start_with?('<') && html_content.strip.end_with?('>')
          :tag
        else
          :block
        end
      end

      # Start a new column context from heading syntax
      def start_column_from_heading(cm_node, title, level)
        # Create caption node if title is provided
        caption_node = if title && !title.empty?
                         node = CaptionNode.new(location: current_location(cm_node))
                         node.add_child(TextNode.new(
                                          location: current_location(cm_node),
                                          content: title
                                        ))
                         node
                       end

        # Create column node with level
        column_node = ColumnNode.new(
          location: current_location(cm_node),
          caption_node: caption_node,
          level: level
        )

        @context.push(column_node)
      end

      # End current column context
      def end_column(_html_node)
        unless @context.current.is_a?(ColumnNode)
          # Warning: /column without matching column
          return
        end

        column_node = @context.current
        @context.pop

        @context.current.add_child(column_node)
      end

      # Add node to current context (column or document)
      def add_node_to_current_context(node)
        current = @context.current
        if current.nil?
          raise ReVIEW::CompileError, "Internal error: No current context. Cannot add #{node.class} node."
        end

        unless current.respond_to?(:add_child)
          raise ReVIEW::CompileError, "Internal error: Current context #{current.class} doesn't support add_child."
        end

        current.add_child(node)
      end

      # Check if paragraph contains only a standalone image
      def standalone_image_paragraph?(cm_node)
        children = cm_node.to_a
        return false if children.empty?

        # Filter out softbreak and linebreak nodes (they're just formatting)
        significant_children = children.reject { |c| %i[softbreak linebreak].include?(c.type) }

        # Pattern 1: Only image node
        if significant_children.length == 1
          return significant_children.first.type == :image
        end

        # Pattern 2: Image node followed by attribute block text
        if significant_children.length == 2
          first = significant_children[0]
          second = significant_children[1]
          if first.type == :image && second.type == :text
            # Check if the text is an attribute block
            text_content = second.string_content.strip
            return !parse_attribute_block(text_content).nil?
          end
        end

        false
      end

      # Process standalone image as block-level ImageNode
      def process_standalone_image(cm_node)
        children = cm_node.to_a
        # Filter out softbreak and linebreak nodes
        significant_children = children.reject { |c| %i[softbreak linebreak].include?(c.type) }

        image_node = significant_children[0] # Get the image node

        # Check if there's an attribute block after the image (second child of paragraph)
        # Pattern: ![alt](url){#id caption="..."}
        attrs = nil
        if significant_children.length == 2 && significant_children[1].type == :text
          text_content = significant_children[1].string_content
          attrs = parse_attribute_block(text_content)
        end

        # Extract image information
        image_id = attrs&.[](:id) || extract_image_id(image_node.url)
        alt_text = extract_text(image_node) # Extract alt text from children
        caption_text = attrs&.[](:caption) || alt_text

        caption_node = if caption_text && !caption_text.empty?
                         node = CaptionNode.new(location: current_location(image_node))
                         node.add_child(TextNode.new(
                                          location: current_location(image_node),
                                          content: caption_text
                                        ))
                         node
                       end

        image_block = ImageNode.new(
          location: current_location(image_node),
          id: image_id,
          caption_node: caption_node,
          content: '',
          image_type: :image
        )

        add_node_to_current_context(image_block)
      end

      # Extract image ID from URL (remove extension if present)
      def extract_image_id(url)
        # Remove file extension for Re:VIEW compatibility
        File.basename(url, '.*')
      end

      # Process footnote definition from Markly
      # Markly parses [^id]: content into :footnote_definition nodes
      def process_footnote_definition(cm_node)
        # Get footnote ID from Markly node's string_content
        footnote_id = cm_node.string_content

        # Create FootnoteNode
        footnote_node = FootnoteNode.new(
          location: current_location(cm_node),
          id: footnote_id,
          footnote_type: :footnote
        )

        # Process footnote content (children of the footnote_definition node)
        # Markly already parsed the content, including inline markup
        @context.with_context(footnote_node) do
          process_children(cm_node)
        end

        add_node_to_current_context(footnote_node)
      end

      # Auto-close columns when encountering a heading at the same or higher level
      def auto_close_columns_for_heading(heading_level)
        # Close columns that are at the same or lower level than the current heading
        while @context.current.is_a?(ColumnNode)
          column_node = @context.current
          column_level = column_node.level

          # If the column was started at the same level or lower, close it
          # (lower level number = higher heading, e.g., # is level 1, ## is level 2)
          break if column_level && heading_level > column_level

          # Close the column
          @context.pop

          # Add completed column to parent context
          @context.current.add_child(column_node)
        end
      end

      # Close all remaining open columns
      def close_all_columns
        while @context.current.is_a?(ColumnNode)
          column_node = @context.current
          @context.pop

          # Add completed column to parent context
          @context.current.add_child(column_node)
        end
      end

      # Parse attribute block in the format {#id .class attr="value"}
      # @param text [String] Text potentially containing attributes
      # @return [Hash, nil] Hash of attributes or nil if not an attribute block
      def parse_attribute_block(text)
        return nil unless text =~ /\A\s*\{([^}]+)\}\s*\z/

        attrs = {}
        attr_text = ::Regexp.last_match(1)

        # Extract ID: #id
        if attr_text =~ /#([a-zA-Z0-9_-]+)/
          attrs[:id] = ::Regexp.last_match(1)
        end

        # Extract caption attribute: caption="..."
        if attr_text =~ /caption=["']([^"']+)["']/
          attrs[:caption] = ::Regexp.last_match(1)
        end

        # Extract classes: .classname
        attrs[:classes] = attr_text.scan(/\.([a-zA-Z0-9_-]+)/).flatten

        attrs.empty? ? nil : attrs
      end

      # Validate that final state is clean after conversion
      def validate_final_state!
        if @context.current != @ast_root
          raise ReVIEW::CompileError, "Internal error: Context not properly restored. Expected to be at root but at #{@context.current.class}"
        end

        # Check for unclosed columns
        column_nodes = @context.find_all(ColumnNode)
        unless column_nodes.empty?
          raise ReVIEW::CompileError, "Internal error: #{column_nodes.length} unclosed column(s) remain"
        end

        @context.validate!
      end
    end
  end
end
