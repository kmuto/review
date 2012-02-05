#
# $Id: book.rb 4315 2009-09-02 04:15:24Z kmuto $
#
# Copyright (c) 2002-2008 Minero Aoki
#               2009 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
module ReVIEW
  module Book
    class Chapter

      def Chapter.intern_pathes(pathes)
        books = {}
        pathes.map {|path|
          basedir = File.dirname(path)
          book = (books[File.expand_path(basedir)] ||= Book.load(basedir))
          begin
            book.chapter(File.basename(path, '.*'))
          rescue KeyError => err
            raise FileNotFound, "no such file: #{path}"
          end
        }
      end

      def Chapter.for_stdin
        new(nil, nil, '-', nil, $stdin)
      end

      def Chapter.for_path(number, path)
        new(nil, number, File.basename(path), path)
      end

      def initialize(book, number, name, path, io = nil)
        @book = book
        @number = number
        @name = name
        @path = path
        @io = io
        @title = nil
        @content = nil
        @list_index = nil
        @table_index = nil
        @footnote_index = nil
        @image_index = nil
        @icon_index = nil
        @numberless_image_index = nil
        @indepimage_index = nil
        @headline_index = nil
      end

      def env
        @book
      end

      def inspect
        "\#<#{self.class} #{@number} #{@path}>"
      end

      attr_reader :book
      attr_reader :number
      attr_reader :path

      def dirname
        return nil unless @path
        File.dirname(@path)
      end

      def basename
        return nil unless @path
        File.basename(@path)
      end

      def name
        File.basename(@name, '.*')
      end

      alias id name

      def title
        @title = ""
        open {|f|
          f.each_line {|l|
            if l =~ /\A=+/
              @title = l.sub(/\A=+/, '').strip
              break
            end
          }
        }
        if ReVIEW.book.param["inencoding"] =~ /^EUC$/
          @title = NKF.nkf("-E -w", @title)
        elsif ReVIEW.book.param["inencoding"] =~ /^SJIS$/
          @title = NKF.nkf("-S -w", @title)
        elsif ReVIEW.book.param["inencoding"] =~ /^JIS$/
          @title = NKF.nkf("-J -w", @title)
        else
          @title = NKF.nkf("-w", @title)
        end
      end

      def size
        File.size(path())
      end

      def volume
        @volume ||= Volume.count_file(path())
      end

      def open(&block)
        return (block_given?() ? yield(@io) : @io) if @io
        File.open(path(), &block)
      end

      def content
        if ReVIEW.book.param["inencoding"] =~ /^EUC$/i
          @content = NKF.nkf("-E -w", File.read(path()))
        elsif ReVIEW.book.param["inencoding"] =~ /^SJIS$/i
          @content = NKF.nkf("-S -w", File.read(path()))
        elsif ReVIEW.book.param["inencoding"] =~ /^JIS$/i
          @content = NKF.nkf("-J -w", File.read(path()))
        else
          @content = NKF.nkf("-w", File.read(path())) # auto detect
        end
      end

      def lines
        # FIXME: we cannot duplicate Enumerator on ruby 1.9 HEAD
        (@lines ||= content().lines.to_a).dup
      end

      def list(id)
        list_index()[id]
      end

      def list_index
        @list_index ||= ListIndex.parse(lines())
        @list_index
      end

      def table(id)
        table_index()[id]
      end

      def table_index
        @table_index ||= TableIndex.parse(lines())
        @table_index
      end

      def footnote(id)
        footnote_index()[id]
      end

      def footnote_index
        @footnote_index ||= FootnoteIndex.parse(lines())
        @footnote_index
      end

      def image(id)
        return image_index()[id] if image_index().has_key?(id)
        return icon_index()[id] if icon_index().has_key?(id)
        return numberless_image_index()[id] if numberless_image_index().has_key?(id)
        indepimage_index()[id]
      end

      def numberless_image_index
        @numberless_image_index ||=
          NumberlessImageIndex.parse(lines(), id(),
          "#{book.basedir}#{@book.image_dir}",
          @book.image_types)
      end

      def image_index
        @image_index ||= ImageIndex.parse(lines(), id(),
          "#{book.basedir}#{@book.image_dir}",
          @book.image_types)
        @image_index
      end

      def icon_index
        @icon_index ||= IconIndex.parse(lines(), id(),
          "#{book.basedir}#{@book.image_dir}",
          @book.image_types)
        @icon_index
      end

      def indepimage_index
        @indepimage_index ||=
          IndepImageIndex.parse(lines(), id(),
          "#{book.basedir}#{@book.image_dir}",
          @book.image_types)
      end

      def bibpaper(id)
        bibpaper_index()[id]
      end

      def bibpaper_index
        raise FileNotFound, "no such bib file: #{@book.bib_file}" unless @book.bib_exist?
        @bibpaper_index ||= BibpaperIndex.parse(@book.read_bib.lines.to_a)
        @bibpaper_index
      end

      def headline(caption)
        headline_index()[caption]
      end

      def headline_index
        @headline_index ||= HeadlineIndex.parse(lines(), self)
      end

      def on_CHAPS?
        @book.read_CHAPS().lines.map(&:strip).include?(id() + @book.ext())
      end
    end
  end
end
