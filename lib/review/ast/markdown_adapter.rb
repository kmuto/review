# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'
require 'review/snapshot_location'
require 'review/ast/markdown_html_node'

module ReVIEW
  module AST
    # MarkdownAdapter - Adapter to convert Markly AST to Re:VIEW AST
    #
    # This class walks the Markly AST and creates corresponding
    # Re:VIEW AST nodes.
    class MarkdownAdapter
      def initialize(compiler)
        @compiler = compiler
        @list_stack = []
        @table_stack = []
        @current_line = 1
        @column_stack = [] # Stack for tracking nested columns
        @pending_nodes = [] # Temporary storage for nodes inside columns
      end

      # Convert Markly document to Re:VIEW AST
      #
      # @param markly_doc [Markly::Node] Markly document root
      # @param ast_root [DocumentNode] Re:VIEW AST root
      # @param chapter [ReVIEW::Book::Chapter] Chapter context (required)
      def convert(markly_doc, ast_root, chapter)
        @ast_root = ast_root
        @current_node = ast_root
        @chapter = chapter

        # Walk the Markly AST
        walk_node(markly_doc)

        # Close any remaining open columns at the end of the document
        close_all_columns
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

        # Check if this is a column end marker: ### [/column]
        if %r{\A\s*\[/column\]\s*\z}.match?(heading_text)
          # End the current column
          end_column_from_heading(cm_node)
        # Check if this is a column start marker: ### [column] Title or ### [column]
        elsif heading_text =~ /\A\s*\[column\](.*)/
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

          caption_text = caption_node.to_text

          # Create headline node
          headline = HeadlineNode.new(
            location: current_location(cm_node),
            level: level,
            label: nil, # Markdown doesn't have explicit labels
            caption: caption_text,
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
        else
          para = ParagraphNode.new(
            location: current_location(cm_node)
          )

          # Process inline content
          process_inline_content(cm_node, para)

          add_node_to_current_context(para)
        end
      end

      # Process list node
      def process_list(cm_node)
        list_node = ListNode.new(
          location: current_location(cm_node),
          list_type: cm_node.list_type == :ordered_list ? :ol : :ul,
          start_number: cm_node.list_type == :ordered_list ? cm_node.list_start : nil
        )

        add_node_to_current_context(list_node)

        # Push list context
        @list_stack.push(@current_node)
        @current_node = list_node

        # Process list items
        process_children(cm_node)

        # Pop list context
        @current_node = @list_stack.pop
      end

      # Process list item node
      def process_list_item(cm_node)
        item = ListItemNode.new(
          location: current_location(cm_node)
        )

        add_node_to_current_context(item)

        # Process item content
        saved_current = @current_node
        @current_node = item

        cm_node.each_with_index do |child, idx|
          if child.type == :paragraph && idx == 0
            # For the first paragraph in a list item, process inline content directly
            process_inline_content(child, item)
          else
            # For other blocks, process normally
            walk_node(child)
          end
        end

        @current_node = saved_current
      end

      # Process code block node
      def process_code_block(cm_node)
        code_info = cm_node.fence_info || ''
        lang = code_info.split(/\s+/).first || nil

        code_block = CodeBlockNode.new(
          location: current_location(cm_node),
          lang: lang,
          code_type: :emlist, # Default to emlist for Markdown code blocks
          original_text: cm_node.string_content
        )

        # Add code lines
        cm_node.string_content.each_line.with_index do |line, idx|
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

        # Process quote content
        saved_current = @current_node
        @current_node = quote_node
        process_children(cm_node)
        @current_node = saved_current
      end

      # Process table node (GFM extension)
      def process_table(cm_node)
        table_node = TableNode.new(
          location: current_location(cm_node)
        )

        add_node_to_current_context(table_node)

        # Process table content
        @table_stack.push(@current_node)
        @current_node = table_node

        process_children(cm_node)

        @current_node = @table_stack.pop
      end

      # Process table row node
      def process_table_row(cm_node)
        row_node = TableRowNode.new(
          location: current_location(cm_node),
          row_type: :body
        )

        @current_node.add_body_row(row_node)

        # Process cells
        saved_current = @current_node
        @current_node = row_node
        process_children(cm_node)
        @current_node = saved_current
      end

      # Process table header node
      def process_table_header(cm_node)
        row_node = TableRowNode.new(
          location: current_location(cm_node),
          row_type: :header
        )

        @current_node.add_header_row(row_node)

        # Process cells
        saved_current = @current_node
        @current_node = row_node
        process_children(cm_node)
        @current_node = saved_current
      end

      # Process table cell node
      def process_table_cell(cm_node)
        cell_type = if @current_node.is_a?(TableRowNode) && @current_node.row_type == :header
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
        if html_node.column_start?
          start_column(html_node)
        elsif html_node.column_end?
          end_column(html_node)
        else
          # Regular HTML content - add to current context
          embed_node = EmbedNode.new(
            location: current_location(cm_node),
            embed_type: :html,
            lines: html_content.lines.map(&:chomp)
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
          parent_node.add_child(TextNode.new(
                                  location: current_location(cm_node),
                                  content: cm_node.string_content
                                ))

        when :strong
          inline_node = InlineNode.new(
            location: current_location(cm_node),
            inline_type: :b,
            args: [extract_text(cm_node)]
          )
          process_inline_content(cm_node, inline_node)
          parent_node.add_child(inline_node)

        when :emph
          inline_node = InlineNode.new(
            location: current_location(cm_node),
            inline_type: :i,
            args: [extract_text(cm_node)]
          )
          process_inline_content(cm_node, inline_node)
          parent_node.add_child(inline_node)

        when :code
          inline_node = InlineNode.new(
            location: current_location(cm_node),
            inline_type: :code,
            args: [cm_node.string_content]
          )
          inline_node.add_child(TextNode.new(
                                  location: current_location(cm_node),
                                  content: cm_node.string_content
                                ))
          parent_node.add_child(inline_node)

        when :link
          # Create href inline node
          inline_node = InlineNode.new(
            location: current_location(cm_node),
            inline_type: :href,
            args: [cm_node.url, extract_text(cm_node)]
          )
          process_inline_content(cm_node, inline_node)
          parent_node.add_child(inline_node)

        when :image
          # Create icon inline node (Re:VIEW's image inline)
          inline_node = InlineNode.new(
            location: current_location(cm_node),
            inline_type: :icon,
            args: [cm_node.url]
          )
          parent_node.add_child(inline_node)

        when :strikethrough
          # GFM extension
          inline_node = InlineNode.new(
            location: current_location(cm_node),
            inline_type: :del,
            args: [extract_text(cm_node)]
          )
          process_inline_content(cm_node, inline_node)
          parent_node.add_child(inline_node)

        when :softbreak
          # Soft line break - convert to space
          parent_node.add_child(TextNode.new(
                                  location: current_location(cm_node),
                                  content: ' '
                                ))

        when :linebreak
          # Hard line break - preserve as newline
          parent_node.add_child(TextNode.new(
                                  location: current_location(cm_node),
                                  content: "\n"
                                ))

        when :html_inline # rubocop:disable Lint/DuplicateBranch
          # Inline HTML - store as text for now
          parent_node.add_child(TextNode.new(
                                  location: current_location(cm_node),
                                  content: cm_node.string_content
                                ))

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
                 @current_line + line_offset
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

      # Start a new column context
      def start_column(html_node)
        title = html_node.column_title

        # Create caption node if title is provided
        caption_node = if title && !title.empty?
                         node = CaptionNode.new(location: html_node.location)
                         node.add_child(TextNode.new(
                                          location: html_node.location,
                                          content: title
                                        ))
                         node
                       end

        # Create column node
        column_node = ColumnNode.new(
          location: html_node.location,
          caption: caption_node&.to_text,
          caption_node: caption_node
        )

        # Push current context to stack
        @column_stack.push({
                             column_node: column_node,
                             previous_node: @current_node
                           })

        # Set column as current context
        @current_node = column_node
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

        # Create column node
        column_node = ColumnNode.new(
          location: current_location(cm_node),
          caption: caption_node&.to_text,
          caption_node: caption_node
        )

        # Push current context to stack with heading level
        @column_stack.push({
                             column_node: column_node,
                             previous_node: @current_node,
                             heading_level: level
                           })

        # Set column as current context
        @current_node = column_node
      end

      # End current column context
      def end_column(_html_node)
        if @column_stack.empty?
          # Warning: /column without matching column
          return
        end

        # Pop column context
        column_context = @column_stack.pop
        column_node = column_context[:column_node]
        previous_node = column_context[:previous_node]

        # Add completed column to previous context
        previous_node.add_child(column_node)

        # Restore previous context
        @current_node = previous_node
      end

      # End current column context from heading syntax
      def end_column_from_heading(_cm_node)
        if @column_stack.empty?
          # Warning: [/column] without matching [column]
          return
        end

        # Pop column context
        column_context = @column_stack.pop
        column_node = column_context[:column_node]
        previous_node = column_context[:previous_node]

        # Add completed column to previous context
        previous_node.add_child(column_node)

        # Restore previous context
        @current_node = previous_node
      end

      # Add node to current context (column or document)
      def add_node_to_current_context(node)
        @current_node.add_child(node)
      end

      # Check if paragraph contains only a standalone image
      def standalone_image_paragraph?(cm_node)
        children = cm_node.to_a
        return false if children.length != 1

        child = children.first
        child.type == :image
      end

      # Process standalone image as block-level ImageNode
      def process_standalone_image(cm_node)
        image_node = cm_node.first # Get the image node

        # Extract image information
        image_id = extract_image_id(image_node.url)
        alt_text = extract_text(image_node) # Extract alt text from children

        # Create caption if alt text exists
        caption_node = if alt_text && !alt_text.empty?
                         node = CaptionNode.new(location: current_location(image_node))
                         node.add_child(TextNode.new(
                                          location: current_location(image_node),
                                          content: alt_text
                                        ))
                         node
                       end

        # Create ImageNode
        image_block = ImageNode.new(
          location: current_location(image_node),
          id: image_id,
          caption: caption_node&.to_text,
          caption_node: caption_node,
          image_type: :image
        )

        add_node_to_current_context(image_block)
      end

      # Extract image ID from URL (remove extension if present)
      def extract_image_id(url)
        # Remove file extension for Re:VIEW compatibility
        File.basename(url, '.*')
      end

      # Auto-close columns when encountering a heading at the same or higher level
      def auto_close_columns_for_heading(heading_level)
        # Close columns that are at the same or lower level than the current heading
        until @column_stack.empty?
          column_context = @column_stack.last
          column_level = column_context[:heading_level]

          # If the column was started at the same level or lower, close it
          # (lower level number = higher heading, e.g., # is level 1, ## is level 2)
          break if column_level && heading_level > column_level

          # Close the column
          @column_stack.pop
          column_node = column_context[:column_node]
          previous_node = column_context[:previous_node]

          # Add completed column to previous context
          previous_node.add_child(column_node)

          # Restore previous context
          @current_node = previous_node
        end
      end

      # Close all remaining open columns
      def close_all_columns
        until @column_stack.empty?
          column_context = @column_stack.pop
          column_node = column_context[:column_node]
          previous_node = column_context[:previous_node]

          # Add completed column to previous context
          previous_node.add_child(column_node)

          # Restore previous context
          @current_node = previous_node
        end
      end
    end
  end
end
