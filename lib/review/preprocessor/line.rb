# Copyright (c) 2010-2021 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

module ReVIEW
  class Preprocessor
    class Line
      def initialize(number, string)
        @number = number
        @string = string
      end

      attr_reader :number
      attr_reader :string
      alias_method :to_s, :string

      def edit
        self.class.new(@number, yield(@string))
      end

      def empty?
        @string.strip.empty?
      end

      def num_indent
        @string.slice(/\A\s*/).size
      end
    end
  end
end
