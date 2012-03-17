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
    class Part
      include Compilable

      def initialize(book, number, chapters, name="")
        @book = book
        @number = number
        @chapters = chapters
        @path = name
        @name = name ? File.basename(name, '.*') : nil
      end

      attr_reader :number
      attr_reader :chapters
      attr_reader :name

      def each_chapter(&block)
        @chapters.each(&block)
      end

      def volume
        Volume.sum(@chapters.map {|chap| chap.volume })
      end

      def file?
        (name.present? and path =~ /\.re\z/) ? true : false
      end

    end
  end
end
