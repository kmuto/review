# Copyright (c) 2008-2019 Minero Aoki, Kenshi Muto
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
require 'review/book/index/item'

module ReVIEW
  module Book
    class Index
      def self.parse(src, *args)
        index = self.new(*args)
        seq = 1
        src.grep(%r{\A//#{item_type}}) do |line|
          if id = line.slice(/\[(.*?)\]/, 1)
            index.add_item(ReVIEW::Book::Index::Item.new(id, seq))
            seq += 1
            if id.empty?
              ReVIEW.logger.warn "warning: no ID of #{item_type} in #{line}"
            end
          end
        end
        index
      end

      include Enumerable

      def item_type
        self.class.item_type
      end

      def initialize
        @index = {}
        @logger = ReVIEW.logger
        @image_finder = nil
      end

      def size
        @index.size
      end

      def add_item(item)
        if @index[item.id] && self.class != ReVIEW::Book::IconIndex
          @logger.warn "warning: duplicate ID: #{item.id} (#{item.inspect})"
        end
        @index[item.id] = item
        if item.class != ReVIEW::Book::Chapter
          item.index = self
        end
      end

      def [](id)
        @index.fetch(id)
      rescue
        if @index.keys.map { |i| i.split('|').last }.flatten. # unfold all ids
           each_with_object(Hash.new(0)) { |i, h| h[i] += 1 }. # number of occurrences
           select { |k, v| k == id && v > 1 }.present? # detect duplicated
          raise KeyError, "key '#{id}' is ambiguous for #{self.class}"
        end

        @index.each_value do |item|
          if item.id.split('|').include?(id)
            return item
          end
        end
        raise KeyError, "not found key '#{id}' for #{self.class}"
      end

      def number(id)
        self[id].number.to_s
      end

      def each(&block)
        @index.values.each(&block)
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
        chapter_item = @index.fetch(id)
        begin
          chapter = chapter_item.content
          chapter.format_number
        rescue # part
          I18n.t('part', chapter.number)
        end
      end

      def title(id)
        @index.fetch(id).content.title
      rescue # non-file part
        @index.fetch(id).content.name
      end

      def display_string(id)
        if number(id)
          I18n.t('chapter_quote', [number(id), title(id)])
        else
          I18n.t('chapter_quote_without_number', title(id))
        end
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

    class EquationIndex < Index
      def self.item_type
        '(texequation)'
      end
    end

    class FootnoteIndex < Index
      def self.parse(src)
        index = self.new
        seq = 1
        src.grep(%r{\A//footnote}) do |line|
          if m = /\[(.*?)\]\[(.*)\]/.match(line)
            m1 = m[1].gsub(/\\(\])/) { $1 }
            m2 = m[2].gsub(/\\(\])/) { $1 }
            index.add_item(Item.new(m1, seq, m2))
          end
          seq += 1
        end
        index
      end
    end

    class ImageIndex < Index
      def self.parse(src, *args)
        index = self.new(*args)
        seq = 1
        src.grep(%r{\A//#{item_type}}) do |line|
          # ex. ["//image", "id", "", "caption"]
          elements = line.split(/\[(.*?)\]/)
          if elements[1].present?
            if line.start_with?('//imgtable')
              index.add_item(ReVIEW::Book::Index::Item.new(elements[1], 0, elements[3]))
            else ## %r<\A//(image|graph)>
              index.add_item(ReVIEW::Book::Index::Item.new(elements[1], seq, elements[3]))
              seq += 1
            end
            if elements[1] == ''
              ReVIEW.logger.warn "warning: no ID of #{item_type} in #{line}"
            end
          end
        end
        index
      end

      def self.item_type
        '(image|graph|imgtable)'
      end

      attr_reader :image_finder

      def initialize(chapid, basedir, types, builder)
        super()
        @chapid = chapid
        @basedir = basedir
        @types = types
        @logger = ReVIEW.logger

        @image_finder = ReVIEW::Book::ImageFinder.new(basedir, chapid, builder, types)
      end

      def find_path(id)
        @image_finder.find_path(id)
      end
    end

    class IconIndex < ImageIndex
      def initialize(chapid, basedir, types, builder)
        @index = {}
        @chapid = chapid
        @basedir = basedir
        @types = types
        @logger = ReVIEW.logger

        @image_finder = ImageFinder.new(basedir, chapid, builder, types)
      end

      def self.parse(src, *args)
        index = self.new(*args)
        seq = 1
        src.grep(/@<icon>/) do |line|
          line.gsub(/@<icon>\{(.+?)\}/) do
            index.add_item(ReVIEW::Book::Index::Item.new($1, seq))
            seq += 1
          end
        end
        index
      end
    end

    class BibpaperIndex < Index
      def self.parse(src)
        index = self.new
        seq = 1
        src.grep(%r{\A//bibpaper}) do |line|
          if m = /\[(.*?)\]\[(.*)\]/.match(line)
            m1 = m[1].gsub(/\\(.)/) { $1 }
            m2 = m[2].gsub(/\\(.)/) { $1 }
            index.add_item(Item.new(m1, seq, m2))
          end
          seq += 1
        end
        index
      end
    end

    class NumberlessImageIndex < ImageIndex
      def self.item_type
        'numberlessimage'
      end

      def number(_id)
        ''
      end
    end

    class IndepImageIndex < ImageIndex
      def self.item_type
        '(indepimage|imgtable)'
      end

      def number(_id)
        ''
      end
    end

    class HeadlineIndex < Index
      HEADLINE_PATTERN = /\A(=+)(?:\[(.+?)\])?(?:\{(.+?)\})?(.*)/

      def self.parse(src, chap)
        headline_index = self.new(chap)
        indexs = []
        headlines = []
        inside_column = false
        inside_block = nil
        column_level = -1
        src.each do |line|
          if line =~ %r{\A//[a-z]+.*\{\Z}
            inside_block = true
            next
          elsif line.start_with?('//}')
            inside_block = nil
            next
          elsif inside_block
            next
          end

          m = HEADLINE_PATTERN.match(line)
          if m.nil? || m[1].size > 10 # Ignore too deep index
            next
          end

          index = m[1].size - 2

          # column
          if m[2] == 'column'
            inside_column = true
            column_level = index
            next
          elsif m[2] == '/column'
            inside_column = false
            next
          end
          if indexs.blank? || index <= column_level
            inside_column = false
          end
          next if inside_column
          next if m[4].strip.empty? # no title

          next unless index >= 0
          if indexs.size > (index + 1)
            unless %w[nonum notoc nodisp].include?(m[2])
              indexs = indexs.take(index + 1)
            end
            headlines = headlines.take(index + 1)
          end
          if indexs[index].nil?
            (0..index).each do |i|
              indexs[i] ||= 0
            end
          end

          if %w[nonum notoc nodisp].include?(m[2])
            headlines[index] = m[3].present? ? m[3].strip : m[4].strip
            item_id = headlines.join('|')
            headline_index.add_item(Item.new(item_id, nil, m[4].strip))
          else
            indexs[index] += 1
            headlines[index] = m[3].present? ? m[3].strip : m[4].strip
            item_id = headlines.join('|')
            headline_index.add_item(Item.new(item_id, indexs.dup, m[4].strip))
          end
        end
        headline_index
      end

      def initialize(chap)
        @chap = chap
        @index = {}
        @logger = ReVIEW.logger
      end

      def number(id)
        unless self[id].number
          # when notoc
          return ''
        end
        n = @chap.number
        # XXX: remove magic number (move to lib/review/book/chapter.rb)
        if @chap.on_appendix? && @chap.number > 0 && @chap.number < 28
          n = @chap.format_number(false)
        end
        ([n] + self[id].number).join('.')
      end
    end

    class ColumnIndex < Index
      COLUMN_PATTERN = /\A(=+)\[column\](?:\{(.+?)\})?(.*)/

      def self.parse(src, *_args)
        index = self.new
        seq = 1
        src.each do |line|
          m = COLUMN_PATTERN.match(line)
          next unless m
          _level = m[1] ## not use it yet
          id = m[2]
          caption = m[3].strip
          id = caption if id.nil? || id.empty?

          index.add_item(ReVIEW::Book::Index::Item.new(id, seq, caption))
          seq += 1
        end
        index
      end
    end
  end
end
