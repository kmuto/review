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
        index_keys = @index.keys.map { |i| i.split('|').last }.flatten # unfold all ids
        if index_keys.each_with_object(Hash.new(0)) { |i, h| h[i] += 1 }. # number of occurrences
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
    end

    class ImageIndex < Index
      def self.item_type
        '(image|graph|imgtable)'
      end

      attr_reader :image_finder

      def initialize(chapter)
        super()
        @chapter = chapter
        book = @chapter.book

        chapid = chapter.id
        basedir = book.imagedir
        builder = book.config['builder']
        types = book.image_types

        @image_finder = ReVIEW::Book::ImageFinder.new(basedir, chapid, builder, types)
      end

      def find_path(id)
        @image_finder.find_path(id)
      end
    end

    class IconIndex < ImageIndex
    end

    class BibpaperIndex < Index
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

      def initialize(chapter)
        super()
        @chapter = chapter
      end

      def number(id)
        unless self[id].number
          # when notoc
          return ''
        end
        n = @chapter.number
        # XXX: remove magic number (move to lib/review/book/chapter.rb)
        if @chapter.on_appendix? && @chapter.number > 0 && @chapter.number < 28
          n = @chapter.format_number(false)
        end
        ([n] + self[id].number).join('.')
      end
    end

    class ColumnIndex < Index
    end
  end
end
