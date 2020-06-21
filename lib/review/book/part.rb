# Copyright (c) 2009-2019 Minero Aoki, Kenshi Muto
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

      def self.mkpart_from_namelistfile(book, path)
        chaps = []
        File.read(path, mode: 'rt:BOM|utf-8').split.each_with_index do |name, number|
          if path =~ /PREDEF/
            chaps << Chapter.mkchap(book, name)
          else
            chaps << Chapter.mkchap(book, name, number + 1)
          end
        end
        Part.mkpart(chaps)
      end

      def self.mkpart_from_namelist(book, names)
        Part.mkpart(names.map { |name| Chapter.mkchap_ifexist(book, name) }.compact)
      end

      def self.mkpart(chaps)
        chaps.empty? ? nil : Part.new(self, nil, chaps)
      end

      # if Part is dummy, `number` is nil.
      #
      def initialize(book, number, chapters, name = '', io = nil)
        @book = book
        @number = number
        @chapters = chapters
        @name = name
        @path = name
        @content = ''
        if io
          @content = io.read
        elsif @path.present? && File.exist?(File.join(@book.config['contentdir'], @path))
          @content = File.read(File.join(@book.config['contentdir'], @path), mode: 'rt:BOM|utf-8')
          @name = File.basename(@name, '.re')
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
        if @number && file?
          vol = Volume.count_file(File.join(@book.config['contentdir'], @path))
        else
          vol = Volume.new(0, 0, 0)
        end
        vol
      end

      def file?
        name.present? and path.end_with?('.re')
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
