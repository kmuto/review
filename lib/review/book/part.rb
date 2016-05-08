#
# $Id: book.rb 4315 2009-09-02 04:15:24Z kmuto $
#
# Copyright (c) 2002-2008 Minero Aoki
#               2009-2016 Minero Aoki, Kenshi Muto
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

      # if Part is dummy, `number` is nil.
      #
      def initialize(book, number, chapters, name = "", io = nil)
        @book = book
        @number = number
        @chapters = chapters
        @name = name ? File.basename(name, '.re') : nil
        @path = name
        if io
          @content = io.read
        elsif @path && File.exist?(@path)
          @content = File.read(@path, :mode => 'r:BOM|utf-8')
        else
          @content = nil
        end
        if file?
          @title = nil
        else
          @title = name
        end
        @volume = nil
      end

      attr_reader :number
      attr_reader :chapters
      attr_reader :name

      def each_chapter(&block)
        @chapters.each(&block)
      end

      def volume
        vol = Volume.sum(@chapters.map {|chap| chap.volume })
        vol.page_per_kbyte = @book.page_metric.page_per_kbyte
        vol
      end

      def file?
        (name.present? and path.end_with?('.re')) ? true : false
      end

      def format_number(heading = true)
        if heading
          "#{I18n.t("part", @number)}"
        else
          "#{@number}"
        end
      end

      def on_APPENDIX?
        false
      end
    end
  end
end
