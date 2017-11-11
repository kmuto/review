# Copyright (c) 2008-2017 Minero Aoki, Kenshi Muto
#               2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of LGPL, see the file "COPYING".
#

require 'review/extentions'
require 'review/exception'
require 'review/book/image_finder'
require 'review/i18n'
require 'review/logger'

module ReVIEW
  module Book
    class Index
      def self.parse(src, *args)
        items = []
        seq = 1
        src.grep(%r{\A//#{item_type}}) do |line|
          if id = line.slice(/\[(.*?)\]/, 1)
            items.push item_class.new(id, seq)
            seq += 1
            ReVIEW.logger.warn "warning: no ID of #{item_type} in #{line}" if id.empty?
          end
        end
        new(items, *args)
      end

      Item = Struct.new(:id, :number)

      def self.item_class
        self::Item
      end

      include Enumerable

      def item_type
        self.class.item_type
      end

      def initialize(items)
        @items = items
        @index = {}
        @logger = ReVIEW.logger
        items.each do |i|
          @logger.warn "warning: duplicate ID: #{i.id} (#{i})" if @index[i.id]
          @index[i.id] = i
        end
        @image_finder = nil
      end

      def [](id)
        @index.fetch(id)
      rescue
        if @index.keys.map { |i| i.split('|').last }.flatten. # unfold all ids
           each_with_object(Hash.new(0)) { |i, h| h[i] += 1 }. # number of occurrences
           select { |k, v| k == id && v > 1 }.present? # detect duplicated
          raise KeyError, "key '#{id}' is ambiguous for #{self.class}"
        end

        @items.each do |i|
          return i if i.id.split('|').include?(id)
        end
        raise KeyError, "not found key '#{id}' for #{self.class}"
      end

      def number(id)
        self[id].number.to_s
      end

      def each(&block)
        @items.each(&block)
      end

      def key?(id)
        @index.key?(id)
      end
      alias_method :has_key?, :key?
    end

    class ChapterIndex < Index
      def item_type
        'chapter'
      end

      def number(id)
        chapter = @index.fetch(id)
        chapter.format_number
      rescue # part
        I18n.t('part', chapter.number)
      end

      def title(id)
        @index.fetch(id).title
      rescue # non-file part
        @index.fetch(id).name
      end

      def display_string(id)
        "#{number(id)}#{I18n.t('chapter_quote', title(id))}"
      end
    end

    class ListIndex < Index
      def self.item_type
        '(list|listnum)'
      end
    end

    class TableIndex < Index
      def self.item_type
        '(table|imgtable)'
      end
    end

    class FootnoteIndex < Index
      Item = Struct.new(:id, :number, :content)

      def self.parse(src)
        items = []
        seq = 1
        src.grep(%r{\A//footnote}) do |line|
          if m = /\[(.*?)\]\[(.*)\]/.match(line)
            m1 = m[1].gsub(/\\(\])/) { $1 }
            m2 = m[2].gsub(/\\(\])/) { $1 }
            items.push Item.new(m1, seq, m2)
          end
          seq += 1
        end
        new(items)
      end
    end

    class ImageIndex < Index
      def self.parse(src, *args)
        items = []
        seq = 1
        src.grep(%r{\A//#{item_type}}) do |line|
          # ex. ["//image", "id", "", "caption"]
          elements = line.split(/\[(.*?)\]/)
          if elements[1].present?
            if line =~ %r{\A//imgtable}
              items.push item_class.new(elements[1], 0, elements[3])
            else ## %r<\A//(image|graph)>
              items.push item_class.new(elements[1], seq, elements[3])
              seq += 1
            end
            ReVIEW.logger.warn "warning: no ID of #{item_type} in #{line}" if elements[1] == ''
          end
        end
        new(items, *args)
      end

      def self.item_type
        '(image|graph|imgtable)'
      end

      class Item
        def initialize(id, number, caption = nil)
          @id = id
          @number = number
          @caption = caption
          @path = nil
        end

        attr_reader :id
        attr_reader :number
        attr_reader :caption
        attr_writer :index # internal use only

        def bound?
          path
        end

        def path
          @path ||= @index.find_path(id)
        end
      end

      attr_reader :image_finder

      def initialize(items, chapid, basedir, types, builder)
        super items
        items.each do |i|
          i.index = self
        end
        @chapid = chapid
        @basedir = basedir
        @types = types

        @image_finder = ReVIEW::Book::ImageFinder.new(basedir, chapid, builder, types)
      end

      def find_path(id)
        @image_finder.find_path(id)
      end
    end

    class IconIndex < ImageIndex
      def initialize(items, chapid, basedir, types, builder)
        @items = items
        @index = {}
        items.each { |i| @index[i.id] = i }
        items.each { |i| i.index = self }
        @chapid = chapid
        @basedir = basedir
        @types = types

        @image_finder = ImageFinder.new(basedir, chapid, builder, types)
      end

      def self.parse(src, *args)
        items = []
        seq = 1
        src.grep(/@<icon>/) do |line|
          line.gsub(/@<icon>\{(.+?)\}/) do
            items.push item_class.new($1, seq)
            seq += 1
          end
        end
        new(items, *args)
      end
    end

    class BibpaperIndex < Index
      Item = Struct.new(:id, :number, :caption)

      def self.parse(src)
        items = []
        seq = 1
        src.grep(%r{\A//bibpaper}) do |line|
          if m = /\[(.*?)\]\[(.*)\]/.match(line)
            m1 = m[1].gsub(/\\(.)/) { $1 }
            m2 = m[2].gsub(/\\(.)/) { $1 }
            items.push Item.new(m1, seq, m2)
          end
          seq += 1
        end
        new(items)
      end
    end

    class NumberlessImageIndex < ImageIndex
      def self.item_type
        'numberlessimage'
      end

      class Item < ImageIndex::Item
      end

      def number(_id)
        ''
      end
    end

    class IndepImageIndex < ImageIndex
      class Item < ImageIndex::Item
      end

      def self.item_type
        '(indepimage|imgtable)'
      end

      def number(_id)
        ''
      end
    end

    class HeadlineIndex < Index
      HEADLINE_PATTERN = /\A(=+)(?:\[(.+?)\])?(?:\{(.+?)\})?(.*)/
      Item = Struct.new(:id, :number, :caption)
      attr_reader :items

      def self.parse(src, chap)
        items = []
        indexs = []
        headlines = []
        inside_column = false
        inside_block = nil
        src.each do |line|
          if line =~ %r{\A//[a-z]+.*\{\Z}
            inside_block = true
            next
          elsif line =~ %r{\A//\}}
            inside_block = nil
            next
          elsif inside_block
            next
          end

          m = HEADLINE_PATTERN.match(line)
          next if m.nil? || m[1].size > 10 # Ignore too deep index
          next if m[4].strip.empty? # no title
          index = m[1].size - 2

          # column
          if m[2] == 'column'
            inside_column = true
            next
          elsif m[2] == '/column'
            inside_column = false
            next
          end
          inside_column = false if indexs.blank? || index <= indexs[-1]
          next if inside_column

          next unless index >= 0
          if indexs.size > (index + 1)
            indexs = indexs.take(index + 1)
            headlines = headlines.take(index + 1)
          end
          (0..index).each { |i| indexs[i] = 0 if indexs[i].nil? } if indexs[index].nil?
          indexs[index] += 1
          headlines[index] = m[3].present? ? m[3].strip : m[4].strip
          items.push Item.new(headlines.join('|'), indexs.dup, m[4].strip)
        end
        new(items, chap)
      end

      def initialize(items, chap)
        @items = items
        @chap = chap
        @index = {}
        items.each do |i|
          @logger.warn "warning: duplicate ID: #{i.id}" if @index[i.id]
          @index[i.id] = i
        end
      end

      def number(id)
        n = @chap.number
        n = @chap.format_number(false) if @chap.on_appendix? && @chap.number > 0 && @chap.number < 28
        ([n] + self[id].number).join('.')
      end
    end

    class ColumnIndex < Index
      COLUMN_PATTERN = /\A(=+)\[column\](?:\{(.+?)\})?(.*)/
      Item = Struct.new(:id, :number, :caption)

      def self.parse(src, *_args)
        items = []
        seq = 1
        src.each do |line|
          m = COLUMN_PATTERN.match(line)
          next unless m
          _level = m[1] ## not use it yet
          id = m[2]
          caption = m[3].strip
          id = caption if id.nil? || id.empty?

          items.push item_class.new(id, seq, caption)
          seq += 1
        end
        new(items)
      end
    end
  end
end
