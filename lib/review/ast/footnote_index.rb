# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    # AST-specific footnote index that properly handles the dual nature
    # of footnotes: inline references (@<fn>{id}) and block definitions (//footnote[id][content])
    class FootnoteIndex
      # Internal footnote entry struct
      Entry = Struct.new(:id, :number, :content, :footnote_node) do
        def initialize(id, number, content: nil, footnote_node: nil)
          super(id, number, content || '', footnote_node)
        end

        # Update entry with new information
        def update(content: nil, footnote_node: nil)
          self.content = content if content && !content.empty?
          self.footnote_node = footnote_node if footnote_node
        end

        # Check if this entry has an AST footnote node
        def footnote_node?
          !footnote_node.nil?
        end
      end

      def initialize
        @entries = {}
        @counter = 0
      end

      # Add or update a footnote entry
      # This method handles both inline references and block definitions intelligently
      def add_or_update(id, content: nil, footnote_node: nil)
        if @entries.key?(id)
          # Update existing entry with new information
          @entries[id].update(content: content, footnote_node: footnote_node)
        else
          # Create new entry
          @counter += 1
          @entries[id] = Entry.new(id, @counter, content: content, footnote_node: footnote_node)
        end

        @entries[id]
      end

      # Get footnote entry by ID
      def [](id)
        @entries[id]
      end

      # Check if footnote exists
      def key?(id)
        @entries.key?(id)
      end

      # Get footnote number
      def number(id)
        entry = @entries[id]
        entry ? entry.number : nil
      end

      # Get all footnote IDs
      def keys
        @entries.keys
      end

      # Get number of footnotes
      def size
        @entries.size
      end

      # Iterate over all entries (for compatibility with Book::Index)
      def each
        return enum_for(:each) unless block_given?

        @entries.each_value do |entry|
          # Convert to Book::Index::Item format for compatibility
          item = ReVIEW::Book::Index::Item.new(entry.id, entry.number, entry.content)
          # Store FootnoteNode for AST rendering
          item.instance_variable_set(:@footnote_node, entry.footnote_node) if entry.footnote_node
          yield item
        end
      end

      # Map over all entries (for compatibility with Enumerable)
      def map
        return enum_for(:map) unless block_given?

        @entries.values.map do |entry|
          # Convert to Book::Index::Item format for compatibility
          item = ReVIEW::Book::Index::Item.new(entry.id, entry.number, entry.content)
          # Store FootnoteNode for AST rendering
          item.instance_variable_set(:@footnote_node, entry.footnote_node) if entry.footnote_node
          yield item
        end
      end

      # Convert to traditional Book::FootnoteIndex for compatibility
      def to_book_index
        book_index = ReVIEW::Book::FootnoteIndex.new
        @entries.each_value do |entry|
          item = ReVIEW::Book::Index::Item.new(entry.id, entry.number, entry.content)
          # Store FootnoteNode for AST rendering
          item.instance_variable_set(:@footnote_node, entry.footnote_node) if entry.footnote_node
          book_index.add_item(item)
        end
        book_index
      end
    end
  end
end
