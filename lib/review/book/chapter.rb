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
require 'review/book/compilable'
module ReVIEW
  module Book
    class Chapter
      include Compilable

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

      attr_reader :number

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

      def inspect
        "\#<#{self.class} #{@number} #{@path}>"
      end

      def on_CHAPS?
        @book.read_CHAPS().lines.map(&:strip).include?(id() + @book.ext())
      end
    end
  end
end
