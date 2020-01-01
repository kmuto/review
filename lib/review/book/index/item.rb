# Copyright (c) 2008-2019 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of LGPL, see the file "COPYING".
#

require 'review/extentions'
require 'review/exception'
require 'review/book/image_finder'
require 'review/i18n'
require 'review/logger'

module ReVIEW
  module Book
    class Index
      class Item
        def initialize(id, number, caption = nil)
          @id = id
          @number = number
          @caption = caption
          @path = nil
          @index = nil
        end

        attr_reader :id
        attr_reader :number
        attr_reader :caption
        attr_accessor :index # internal use only

        alias_method :content, :caption

        def path
          @path ||= @index.find_path(id)
        end
      end
    end
  end
end
