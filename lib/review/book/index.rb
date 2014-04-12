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
      end

      def [](id)
        @index.fetch(id)
      rescue
        raise KeyError
      end

      def number(id)
        @index.fetch(id).number.to_s
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
        if chapter.on_CHAPS?
          "#{I18n.t("chapter", chapter.number)}"
        elsif chapter.on_PREDEF?
          "#{chapter.number}"
        elsif chapter.on_POSTDEF?
          "#{I18n.t("appendix", chapter.number)}"
        end
      end

      def title(id)
        @index.fetch(id).title
      end

      def display_string(id)
        "#{number(id)}「#{title(id)}」"
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
      class Item
        @@entries = nil

        def initialize(id, number)
          @id = id
          @number = number
          @pathes = nil
        end

        attr_reader :id
        attr_reader :number
        attr_writer :index    # internal use only

        def bound?
          not pathes().empty?
        end

        def path
          pathes().first
        end

        def pathes
          @pathes ||= @index.find_pathes(id)
        end
      end

      def ImageIndex.item_type
        '(image|graph)'
      end

      def initialize(items, chapid, basedir, types)
        super items
        items.each do |i|
          i.index = self
        end
        @chapid = chapid
        @basedir = basedir
        @types = types

        @@entries ||= get_entries
      end

      def get_entries
        Dir.glob(File.join(@basedir, "**/*.*"))
      end

      # internal use only
      def find_pathes(id)
        pathes = []

        # 1. <basedir>/<builder>/<chapid>/<id>.<ext>
        target = "#{@basedir}/#{ReVIEW.book.param['builder']}/#{@chapid}/#{id}"
        @types.each {|ext| pathes.push("#{target}#{ext}") if @@entries.include?("#{target}#{ext}")}

        # 2. <basedir>/<builder>/<chapid>-<id>.<ext>
        target = "#{@basedir}/#{ReVIEW.book.param['builder']}/#{@chapid}-#{id}"
        @types.each {|ext| pathes.push("#{target}#{ext}") if @@entries.include?("#{target}#{ext}")}

        # 3. <basedir>/<builder>/<id>.<ext>
        target = "#{@basedir}/#{ReVIEW.book.param['builder']}/#{id}"
        @types.each {|ext| pathes.push("#{target}#{ext}") if @@entries.include?("#{target}#{ext}")}

        # 4. <basedir>/<chapid>/<id>.<ext>
        target = "#{@basedir}/#{@chapid}/#{id}"
        @types.each {|ext| pathes.push("#{target}#{ext}") if @@entries.include?("#{target}#{ext}")}

        # 5. <basedir>/<chapid>-<id>.<ext>
        target = "#{@basedir}/#{@chapid}-#{id}"
        @types.each {|ext| pathes.push("#{target}#{ext}") if @@entries.include?("#{target}#{ext}")}

        # 6. <basedir>/<id>.<ext>
        target = "#{@basedir}/#{id}"
        @types.each {|ext| pathes.push("#{target}#{ext}") if @@entries.include?("#{target}#{ext}")}

        return pathes
      end
    end

    class IconIndex < ImageIndex
      def initialize(items, chapid, basedir, types)
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

        @@entries ||= get_entries
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
        def initialize(id, number)
          @id = id
          @number = ""
          @pathes = nil
        end
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
        def initialize(id, number)
          @id = id
          @number = ""
          @pathes = nil
        end
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

      def HeadlineIndex.parse(src, chap)
        items = []
        indexs = []
        headlines = []
        src.each do |line|
          if m = HEADLINE_PATTERN.match(line)
            next if m[2] == 'column'
            index = m[1].size - 2
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
        return ([@chap.number] + @index.fetch(id).number).join(".")
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

      def number(id)
        ""
      end

    end

  end
end
