# Copyright (c) 2009-2017 Minero Aoki, Kenshi Muto
#               2002-2008 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
require 'review/textutils'

module ReVIEW
  module Book
    module Compilable
      include TextUtils
      attr_reader :book
      attr_reader :path

      def env
        @book
      end

      def dirname
        return nil unless @path
        File.dirname(@path)
      end

      def basename
        return nil unless @path
        File.basename(@path)
      end

      def name
        return nil unless @name
        File.basename(@name, '.*')
      end

      alias_method :id, :name

      def title
        return @title if @title

        @title = ''
        return @title unless content
        content.each_line do |line|
          if line =~ /\A=+/
            @title = line.sub(/\A=+(\[.+?\])?(\{.+?\})?/, '').strip
            break
          end
        end
        @title
      end

      def size
        content.size
      end

      def volume
        unless @volume
          @volume = Volume.count_file(path)
          @volume.page_per_kbyte = @book.page_metric.page_per_kbyte
        end
        @volume
      end

      # deprecated; use content()
      def open(&_block)
        return (block_given? ? yield(@io) : @io) if @io
        StringIO.new(content)
      end

      attr_writer :content

      def content
        @content
      end

      def lines
        # FIXME: we cannot duplicate Enumerator on ruby 1.9 HEAD
        (@lines ||= content.lines.to_a).dup
      end

      def list(id)
        list_index[id]
      end

      def list_index
        @list_index ||= ListIndex.parse(lines)
        @list_index
      end

      def table(id)
        table_index[id]
      end

      def table_index
        @table_index ||= TableIndex.parse(lines)
        @table_index
      end

      def footnote(id)
        footnote_index[id]
      end

      def footnote_index
        @footnote_index ||= FootnoteIndex.parse(lines)
        @footnote_index
      end

      def image(id)
        return image_index[id] if image_index.key?(id)
        return icon_index[id] if icon_index.key?(id)
        return numberless_image_index[id] if numberless_image_index.key?(id)
        indepimage_index[id]
      end

      def numberless_image_index
        @numberless_image_index ||=
          NumberlessImageIndex.parse(lines, id,
                                     "#{book.basedir}/#{@book.config['imagedir']}",
                                     @book.image_types, @book.config['builder'])
      end

      def image_index
        @image_index ||= ImageIndex.parse(lines, id,
                                          "#{book.basedir}/#{@book.config['imagedir']}",
                                          @book.image_types, @book.config['builder'])
        @image_index
      end

      def icon_index
        @icon_index ||= IconIndex.parse(lines, id,
                                        "#{book.basedir}/#{@book.config['imagedir']}",
                                        @book.image_types, @book.config['builder'])
        @icon_index
      end

      def indepimage_index
        @indepimage_index ||=
          IndepImageIndex.parse(lines, id,
                                "#{book.basedir}/#{@book.config['imagedir']}",
                                @book.image_types, @book.config['builder'])
      end

      def bibpaper(id)
        bibpaper_index[id]
      end

      def bibpaper_index
        raise FileNotFound, "no such bib file: #{@book.bib_file}" unless @book.bib_exist?
        @bibpaper_index ||= BibpaperIndex.parse(@book.read_bib.lines.to_a)
        @bibpaper_index
      end

      def headline(caption)
        headline_index[caption]
      end

      def headline_index
        @headline_index ||= HeadlineIndex.parse(lines, self)
      end

      def column(id)
        column_index[id]
      end

      def column_index
        @column_index ||= ColumnIndex.parse(lines)
      end

      def next_chapter
        book.next_chapter(self)
      end

      def prev_chapter
        book.prev_chapter(self)
      end
    end
  end
end
