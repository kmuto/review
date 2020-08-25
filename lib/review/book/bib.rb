#
# Copyright (c) 2009-2020 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
require 'review/book/book_unit'
require 'review/lineinput'
require 'review/preprocessor'

module ReVIEW
  module Book
    class Bib < BookUnit
      def number
        nil
      end
    end
  end
end
