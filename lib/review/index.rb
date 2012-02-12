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
      "第#{@index.fetch(id).number}章"
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
          items.push Item.new(m[1], seq, m[2])
        end
        seq += 1
      end
      new(items)
    end
  end


  class ImageIndex < Index
    class Item
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
    end

    # internal use only
    def find_pathes(id)
      if ReVIEW.book.param["subdirmode"]
        re = /\A#{id}(?i:#{@types.join('|')})\z/x
        entries().select {|ent| re =~ ent }\
          .sort_by {|ent| @types.index(File.extname(ent).downcase) }\
          .map {|ent| "#{@basedir}/#{@chapid}/#{ent}" }
      elsif ReVIEW.book.param["singledirmode"]
        re = /\A#{id}(?i:#{@types.join('|')})\z/x
        entries().select {|ent| re =~ ent }\
          .sort_by {|ent| @types.index(File.extname(ent).downcase) }\
          .map {|ent| "#{@basedir}/#{ent}" }
      else
        re = /\A#{@chapid}-#{id}(?i:#{@types.join('|')})\z/x
        entries().select {|ent| re =~ ent }\
          .sort_by {|ent| @types.index(File.extname(ent).downcase) }\
          .map {|ent| "#{@basedir}/#{ent}" }
      end
    end

    private

    def entries
      # @entries: do not cache for graph
      if ReVIEW.book.param["subdirmode"]
        @entries = Dir.entries(File.join(@basedir, @chapid))
      else
        @entries = Dir.entries(@basedir)
      end
    rescue Errno::ENOENT
      @entries = []
    end
  end

  class IconIndex < ImageIndex
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
          items.push Item.new(m[1], seq, m[2])
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
    Item = Struct.new(:id, :number, :caption)

    def HeadlineIndex.parse(src, chap)
      items = []
      indexs = []
      headlines = []
      src.each do |line|
        if m = /\A(=+)(?:\[(.+?)\])?(?:\{(.+?)\})?(.*)/.match(line)
          next if m[2] == 'column'
          index = m[1].size - 2
          if index >= 0
            if indexs.size > (index + 1)
              indexs = indexs.take(index + 1)
              headlines = headlines.take(index + 1)
            end
            indexs << 0 if indexs[index].nil?
            indexs[index] += 1
            headlines[index] = m[4].strip
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
end
