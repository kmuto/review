# Copyright (c) 2009-2017 Minero Aoki, Kenshi Muto
#               2002-2008 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
module ReVIEW
  module Book
    class PageMetric
      MetricData = Struct.new(:n_lines, :n_columns)

      def initialize(list_lines, list_columns, text_lines, text_columns, page_per_kbyte)
        @list = MetricData.new(list_lines, list_columns)
        @text = MetricData.new(text_lines, text_columns)
        @page_per_kbyte = page_per_kbyte
      end

      A5 = PageMetric.new(46, 80, 30, 74, 1)
      B5 = PageMetric.new(46, 80, 30, 74, 2)

      attr_reader :list
      attr_reader :text
      attr_reader :page_per_kbyte

      def ==(other)
        self.list == other.list && self.text == other.text && self.page_per_kbyte == other.page_per_kbyte
      end
    end
  end
end
