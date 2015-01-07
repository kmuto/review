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
    ROMAN = %w[0 I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII XVIII XIX XX XXI XXII XXIII XXIV XXV XXVI XXVII]
    ALPHA = %w[0 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z]
    
    class Chapter
      include Compilable

      attr_reader :number, :book

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
        @column_index = nil
      end

      def inspect
        "\#<#{self.class} #{@number} #{@path}>"
      end

      def format_number(heading = true)
        if on_PREDEF?
          return "#{@number}"
        end

        if on_APPENDIX?
          return "#{@number}" if @number < 1 || @number > 27

          type = @book.config["appendix_format"].blank? ? "arabic" : @book.config["appendix_format"].downcase.strip
          appendix = case type
                       when "roman"
                         ROMAN[@number]
                       when "alphabet", "alpha"
                         ALPHA[@number]
                       else
                         # nil, "arabic", etc...
                         "#{@number}"
                     end
          if heading
            return "#{I18n.t("appendix", appendix)}"
          else
            return "#{appendix}"
          end
        end

        if heading
          "#{I18n.t("chapter", @number)}"
        else
          "#{@number}"
        end
      end

      def on_CHAPS?
        on_FILE?(@book.read_CHAPS)
      end

      def on_PREDEF?
        on_FILE?(@book.read_PREDEF)
      end

      def on_APPENDIX?
        on_FILE?(@book.read_APPENDIX)
      end

      def on_POSTDEF?
        on_FILE?(@book.read_POSTDEF)
      end

      private
      def on_FILE?(contents)
        contents.lines.map(&:strip).include?(id() + @book.ext())
      end
    end
  end
end
