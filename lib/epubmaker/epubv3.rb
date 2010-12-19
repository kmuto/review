# encoding: utf-8
# = epubv3.rb -- EPUB version 3 producer.
#
# Copyright (c) 2010 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'epubmaker/epubv2'

module EPUBMaker
  
  # EPUBv3 is EPUB version 3 producer.
  class EPUBv3 < EPUBv2
    # FIXME: waiting EPUBv3 specification fix. opf and ncx will be changed.
  end
end
