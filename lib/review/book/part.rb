# Copyright (c) 2009-2017 Minero Aoki, Kenshi Muto
#               2002-2008 Minero Aoki
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
      def initialize(book, number, chapters, name = '', io = nil)
        @book = book
        @number = number
        @chapters = chapters
        @name = name
        @path = name
        @content = nil
        if io
          @content = io.read
        elsif @path && File.exist?(@path)
          @content = File.read(@path, mode: 'r:BOM|utf-8')
          @name = File.basename(@name, '.re')
        end
        @title = name
        @title = nil if file?
        @volume = nil
      end

      attr_reader :number
      attr_reader :chapters
      attr_reader :name

      def each_chapter(&block)
        @chapters.each(&block)
      end

      def volume
        vol = Volume.sum(@chapters.map(&:volume))
        vol.page_per_kbyte = @book.page_metric.page_per_kbyte
        vol
      end

      def file?
        name.present? and path.end_with?('.re') ? true : false
      end

      def format_number(heading = true)
        if heading
          I18n.t('part', @number)
        else
          @number.to_s
        end
      end

      def on_appendix?
        false
      end

      # backward compatibility
      alias_method :on_APPENDIX?, :on_appendix?
    end
  end
end
