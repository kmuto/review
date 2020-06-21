# Copyright (c) 2009-2020 Minero Aoki, Kenshi Muto
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

      def initialize(list_lines, list_columns, text_lines, text_columns, _page_per_kbyte = 1)
        # page_per_kbyte is obsolete. Just for backward compatibility
        @list = MetricData.new(list_lines, list_columns)
        @text = MetricData.new(text_lines, text_columns)
      end

      # based on review-jsbook's default
      A5 = PageMetric.new(40, 34, 29, 34)
      B5 = PageMetric.new(50, 40, 36, 40)

      attr_reader :list
      attr_reader :text

      def ==(other)
        self.list == other.list && self.text == other.text
      end
    end
  end
end
