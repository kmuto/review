# frozen_string_literal: true

require_relative 'visitor'

module ReVIEW
  module AST
    # Compares two AST nodes for structural equivalence using the Visitor pattern
    # (ignoring location information)
    class Comparator < Visitor
      # Result of AST comparison
      class Result
        attr_reader :differences

        def initialize
          @differences = []
        end

        # Add a difference to the result
        def add_difference(path, message)
          @differences << "#{path}: #{message}"
        end

        # Check if the comparison was successful (no differences)
        def equal?
          @differences.empty?
        end

        # Get a human-readable summary of differences
        def to_s
          if equal?
            'AST nodes are equivalent'
          else
            "AST nodes differ:\n  " + @differences.join("\n  ")
          end
        end
      end

      # Compare two AST nodes and return a Result
      #
      # @param node1 [AST::Node] First node to compare
      # @param node2 [AST::Node] Second node to compare
      # @param path [String] Path to current node (for error messages)
      # @return [Result] Result of comparison
      def compare(node1, node2, path = 'root')
        @node2 = node2
        @path = path
        @result = Result.new

        compare_nodes(node1)

        @result
      end

      private

      # Override visit to handle two-node comparison
      def compare_nodes(node1)
        # Both should be nil or both should be non-nil
        if node1.nil? && @node2.nil?
          return
        elsif node1.nil?
          @result.add_difference(@path, "node1 is nil but node2 is #{@node2.class}")
          return
        elsif @node2.nil?
          @result.add_difference(@path, "node1 is #{node1.class} but node2 is nil")
          return
        end

        # Node types should match
        unless node1.instance_of?(@node2.class)
          @result.add_difference(@path, "node types differ (#{node1.class} vs #{@node2.class})")
          return
        end

        # Visit the node using the visitor pattern
        visit(node1)
      end

      # Compare common attributes and recurse into children
      def compare_common(node1, &block)
        # Compare node-specific attributes if block is provided
        yield if block

        # Compare children recursively
        compare_children(node1)
      end

      # Compare a specific attribute
      def compare_attr(node1, attr, name)
        val1 = node1.send(attr)
        val2 = @node2.send(attr)
        return if val1 == val2

        @result.add_difference(@path, "#{name} mismatch (#{val1.inspect} vs #{val2.inspect})")
      end

      # Compare children arrays
      def compare_children(node1)
        children1 = node1.respond_to?(:children) ? node1.children : []
        children2 = @node2.respond_to?(:children) ? @node2.children : []

        if children1.size != children2.size
          @result.add_difference(@path, "children count mismatch (#{children1.size} vs #{children2.size})")
          return
        end

        children1.zip(children2).each_with_index do |(child1, child2), index|
          # Save current state
          saved_node2 = @node2
          saved_path = @path

          # Update state for child comparison
          @node2 = child2
          @path = "#{saved_path}[#{index}]"

          compare_nodes(child1)

          # Restore state
          @node2 = saved_node2
          @path = saved_path
        end
      end

      # Compare two child nodes (for special children like caption_node)
      def compare_child_node(node1, node2, child_path)
        # Save current state
        saved_node2 = @node2
        saved_path = @path

        # Update state for child comparison
        @node2 = node2
        @path = "#{saved_path}.#{child_path}"

        compare_nodes(node1)

        # Restore state
        @node2 = saved_node2
        @path = saved_path
      end

      # Visitor methods for each node type

      def visit_document(node)
        compare_common(node)
      end

      def visit_headline(node)
        compare_common(node) do
          compare_attr(node, :level, 'headline level')
          compare_attr(node, :label, 'headline label')
          compare_child_node(node.caption_node, @node2.caption_node, 'caption')
        end
      end

      def visit_text(node)
        compare_attr(node, :content, 'text content')
      end

      def visit_paragraph(node)
        compare_common(node)
      end

      def visit_inline(node)
        compare_common(node) do
          compare_attr(node, :inline_type, 'inline type')
          # args comparison can be lenient as they might be reconstructed differently
        end
      end

      def visit_code_block(node)
        compare_common(node) do
          compare_attr(node, :id, 'code block id') if node.id || @node2.id
          compare_attr(node, :lang, 'code block lang') if node.lang || @node2.lang
          compare_attr(node, :line_numbers, 'code block line_numbers')
        end
      end

      def visit_code_line(node)
        compare_common(node)
      end

      def visit_table(node)
        compare_common(node) do
          compare_attr(node, :id, 'table id') if node.id || @node2.id
          compare_attr(node, :table_type, 'table type')
        end
      end

      def visit_table_row(node)
        compare_common(node) do
          compare_attr(node, :row_type, 'table row type')
        end
      end

      def visit_table_cell(node)
        compare_common(node)
      end

      def visit_image(node)
        compare_common(node) do
          compare_attr(node, :id, 'image id') if node.id || @node2.id
          compare_attr(node, :metric, 'image metric') if node.metric || @node2.metric
        end
      end

      def visit_list(node)
        compare_common(node) do
          compare_attr(node, :list_type, 'list type')
        end
      end

      def visit_list_item(node)
        compare_common(node) do
          compare_attr(node, :level, 'list item level')
          compare_attr(node, :item_type, 'list item type') if node.item_type || @node2.item_type

          # Compare term_children for definition lists
          if node.term_children&.any? || @node2.term_children&.any?
            term_children1 = node.term_children || []
            term_children2 = @node2.term_children || []

            if term_children1.size == term_children2.size
              term_children1.zip(term_children2).each_with_index do |(term1, term2), index|
                compare_child_node(term1, term2, "term[#{index}]")
              end
            else
              @result.add_difference(@path, "term_children count mismatch (#{term_children1.size} vs #{term_children2.size})")
            end
          end
        end
      end

      def visit_block(node)
        compare_common(node) do
          compare_attr(node, :block_type, 'block type')
        end
      end

      def visit_minicolumn(node)
        compare_common(node) do
          compare_attr(node, :minicolumn_type, 'minicolumn type')
        end
      end

      def visit_column(node)
        compare_common(node) do
          compare_attr(node, :level, 'column level')
          compare_attr(node, :label, 'column label') if node.label || @node2.label
          compare_attr(node, :column_type, 'column type') if node.column_type || @node2.column_type
        end
      end

      def visit_caption(node)
        compare_common(node)
      end

      def visit_footnote(node)
        compare_common(node) do
          compare_attr(node, :id, 'footnote id')
          compare_attr(node, :footnote_type, 'footnote type')
        end
      end

      def visit_reference(node)
        compare_common(node) do
          compare_attr(node, :ref_id, 'reference ref_id')
          compare_attr(node, :context_id, 'reference context_id')
        end
      end

      def visit_embed(node)
        compare_common(node) do
          compare_attr(node, :embed_type, 'embed type')
          compare_attr(node, :content, 'embed content')
          # target_builders is an array - compare it
          if node.target_builders != @node2.target_builders
            @result.add_difference(@path, "target_builders mismatch (#{node.target_builders.inspect} vs #{@node2.target_builders.inspect})")
          end
        end
      end

      def visit_tex_equation(node)
        compare_common(node) do
          compare_attr(node, :id, 'tex equation id') if node.id || @node2.id
          compare_attr(node, :content, 'tex equation content')
        end
      end

      def visit_markdown_html(node)
        compare_common(node) do
          compare_attr(node, :content, 'markdown html content')
        end
      end
    end
  end
end
