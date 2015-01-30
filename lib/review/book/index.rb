# encoding: utf-8
#
# Copyright (c) 2002-2007 Minero Aoki
#               2008-2009 Minero Aoki, Kenshi Muto
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

module ReVIEW
  module Book
    class Index
      def Index.parse(src, *args)
        items = []
        seq = 1
        src.grep(%r<^//#{item_type()}>) do |line|
          if id = line.slice(/\[(.*?)\]/, 1)
            items.push item_class().new(id, seq)
            seq += 1
            if id == ""
              warn "warning: no ID of #{item_type()} in #{line}"
            end
          end
        end
        new(items, *args)
      end

      Item = Struct.new(:id, :number)

      def Index.item_class
        self::Item
      end

      include Enumerable

      def item_type
        self.class.item_type
      end

      def initialize(items)
        @items = items
        @index = {}
        items.each do |i|
          warn "warning: duplicate ID: #{i.id} (#{i})" unless @index[i.id].nil?
          @index[i.id] = i
        end
        @image_finder = nil
      end

      def [](id)
        @index.fetch(id)
      rescue
        if @index.keys.map{|i| i.split(/\|/) }.flatten. # unfold all ids
            reduce(Hash.new(0)){|h, i| h[i] += 1; h}.  # number of occurrences
            select{|k, v| k == id && v > 1 }.present? # detect duplicated
          raise KeyError, "key '#{id}' is ambiguous for #{self.class}"
        end
        @items.each do |i|
          if i.id.split(/\|/).include?(id)
            return i
          end
        end
        raise KeyError, "not found key '#{id}' for #{self.class}"
      end

      def number(id)
        self[id].number.to_s
      end

      def each(&block)
        @items.each(&block)
      end

      def has_key?(id)
        return @index.has_key?(id)
      end
    end


    class ChapterIndex < Index
      def item_type
        'chapter'
      end

      def number(id)
        chapter = @index.fetch(id)
        chapter.format_number
      rescue # part
        "#{I18n.t("part", chapter.number)}"
      end

      def title(id)
        @index.fetch(id).title
      rescue # non-file part
        @index.fetch(id).name
      end

      def display_string(id)
        "#{number(id)}#{I18n.t("chapter_quote", title(id))}"
      end
    end


    class ListIndex < Index
      def ListIndex.item_type
        '(list|listnum)'
      end
    end


    class TableIndex < Index
      def TableIndex.item_type
        'table'
      end
    end


    class FootnoteIndex < Index
      Item = Struct.new(:id, :number, :content)

      def FootnoteIndex.parse(src)
        items = []
        seq = 1
        src.grep(%r<^//footnote>) do |line|
          if m = /\[(.*?)\]\[(.*)\]/.match(line)
            m1 = m[1].gsub(/\\(\])/){$1}
            m2 = m[2].gsub(/\\(\])/){$1}
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
        src.grep(%r<^//#{item_type()}>) do |line|
          # ex. ["//image", "id", "", "caption"]
          elements = line.split(/\[(.*?)\]/)
          if elements[1].present?
            items.push item_class().new(elements[1], seq, elements[3])
            seq += 1
            if elements[1] == ""
              warn "warning: no ID of #{item_type()} in #{line}"
            end
          end
        end
        new(items, *args)
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
        attr_writer :index    # internal use only

        def bound?
          path
        end

        def path
          @path ||= @index.find_path(id)
        end
      end

      def ImageIndex.item_type
        '(image|graph)'
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

        @image_finder = ReVIEW::Book::ImageFinder.new(basedir, chapid,
                                                      builder, types)
      end

      def find_path(id)
        @image_finder.find_path(id)
      end
    end

    class IconIndex < ImageIndex
      def initialize(items, chapid, basedir, types, builder)
        @items = items
        @index = {}
        items.each do |i|
          ## warn "warning: duplicate ID: #{i.id} (#{i})" unless @index[i.id].nil?
          @index[i.id] = i
        end
        items.each do |i|
          i.index = self
        end
        @chapid = chapid
        @basedir = basedir
        @types = types

        @image_finder = ImageFinder.new(basedir, chapid, builder, types)
      end

      def IconIndex.parse(src, *args)
        items = []
        seq = 1
        src.grep(%r!@<icon>!) do |line|
          line.gsub(/@<icon>\{(.+?)\}/) do |m|
            items.push item_class().new($1, seq)
            seq += 1
          end
        end
        new(items, *args)
      end
    end

    class FormatRef
      def initialize(locale, index)
        @locale = locale
        @index = index
      end

      def title(id)
        sprintf(@locale["#{@index.item_type}_caption_format".intern],
          @index.title(id))
      end

      def number(id)
        sprintf(@locale["#{@index.item_type}_number_format".intern],
          @index.number(id))
      end

      def method_missing(mid, *args, &block)
        super unless @index.respond_to?(mid)
        @index.__send__(mid, *args, &block)
      end
    end

    class BibpaperIndex < Index
      Item = Struct.new(:id, :number, :caption)

      def BibpaperIndex.parse(src)
        items = []
        seq = 1
        src.grep(%r<^//bibpaper>) do |line|
          if m = /\[(.*?)\]\[(.*)\]/.match(line)
            m1 = m[1].gsub(/\\(.)/){$1}
            m2 = m[2].gsub(/\\(.)/){$1}
            items.push Item.new(m1, seq, m2)
          end
          seq += 1
        end
        new(items)
      end
    end

    class NumberlessImageIndex < ImageIndex
      class Item < ImageIndex::Item
      end

      def NumberlessImageIndex.item_type
        'numberlessimage'
      end

      def number(id)
        ""
      end
    end

    class IndepImageIndex < ImageIndex
      class Item < ImageIndex::Item
      end

      def IndepImageIndex.item_type
        'indepimage'
      end

      def number(id)
        ""
      end
    end

    class HeadlineIndex < Index
      HEADLINE_PATTERN = /\A(=+)(?:\[(.+?)\])?(?:\{(.+?)\})?(.*)/
      Item = Struct.new(:id, :number, :caption)
      attr_reader :items

      def HeadlineIndex.parse(src, chap)
        items = []
        indexs = []
        headlines = []
        inside_column = false
        src.each do |line|
          if m = HEADLINE_PATTERN.match(line)
            next if m[1].size > 10 # Ignore too deep index
            index = m[1].size - 2

            # column
            if m[2] == 'column'
              inside_column = true
              next
            end
            if m[2] == '/column'
              inside_column = false
              next
            end
            if indexs.blank? || index <= indexs[-1]
              inside_column = false
            end
            if inside_column
              next
            end

            if index >= 0
              if indexs.size > (index + 1)
                indexs = indexs.take(index + 1)
                headlines = headlines.take(index + 1)
              end
              if indexs[index].nil?
                (0..index).each{|i| indexs[i] = 0 if indexs[i].nil?}
              end
              indexs[index] += 1
              headlines[index] = m[3].present? ? m[3].strip : m[4].strip
              items.push Item.new(headlines.join("|"), indexs.dup, m[4].strip)
            end
          end
        end
        new(items, chap)
      end

      def initialize(items, chap)
        @items = items
        @chap = chap
        @index = {}
        items.each do |i|
          warn "warning: duplicate ID: #{i.id}" unless @index[i.id].nil?
          @index[i.id] = i
        end
      end

      def number(id)
        n = @chap.number
        if @chap.on_APPENDIX? && @chap.number > 0 && @chap.number < 28
          type = @chap.book.config["appendix_format"].blank? ? "arabic" : @chap.book.config["appendix_format"].downcase.strip
          n = case type
              when "roman"
                ROMAN[@chap.number]
              when "alphabet", "alpha"
                ALPHA[@chap.number]
              else
                # nil, "arabic", etc...
                "#{@chap.number}"
              end
        end
        return ([n] + self[id].number).join(".")
      end
    end

    class ColumnIndex < Index
      COLUMN_PATTERN = /\A(=+)\[column\](?:\{(.+?)\})?(.*)/
      Item = Struct.new(:id, :number, :caption)

      def ColumnIndex.parse(src, *args)
        items = []
        seq = 1
        src.each do |line|
          if m = COLUMN_PATTERN.match(line)
            level = m[1] ## not use it yet
            id = m[2]
            caption = m[3].strip
            if !id || id == ""
              id = caption
            end

            items.push item_class().new(id, seq, caption)
            seq += 1
          end
        end
        new(items)
      end

    end

  end
end
