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

require 'review/exception'
require 'review/extentions'
require 'forwardable'
require 'nkf'

require 'review/book/base'
require 'review/book/chapter'
require 'review/book/part'
require 'review/book/page_metric'
require 'review/book/volume'
require 'review/book/index'

module ReVIEW
  @default_book = nil

  def ReVIEW.book
    @default_book ||= Book::Base.load
  end

  module Book
    def self.load_default
      Base.load_default
    end

    def self.load(dir)
      Base.load dir
    end

    def self.update_rubyenv(dir)
      Base.update_rubyenv dir
    end
  end
end
