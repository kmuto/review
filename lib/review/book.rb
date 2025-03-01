# frozen_string_literal: true

# Copyright (c) 2009-2017 Minero Aoki, Kenshi Muto
#               2002-2008 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'review/exception'

require 'review/book/base'
require 'review/book/chapter'
require 'review/book/part'
require 'review/book/page_metric'
require 'review/book/volume'
require 'review/book/index'

module ReVIEW
  module Book
    def self.load(_dir)
      raise NotImplementedError, 'ReVIEW::Book.load is obsoleted. Please use ReVIEW::Book::Base.new.'
    end
  end
end
