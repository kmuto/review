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
module ReVIEW
  module Book
    class Parameters
      def initialize(params = {})
        @chapter_file = '/CHAPS'
        @part_file    = '/PART'
        @reject_file  = '/REJECT'
        @predef_file  = '/PREDEF'
        @postdef_file = '/POSTDEF'
        @page_metric  = PageMetric.a5
        @ext          = '.re'
        @image_dir    = '/images'
        @image_types  = %w( .ai .psd .eps .pdf .tif .tiff .png .bmp .jpg .jpeg .gif .svg )
        @bib_file     = "/bib#{@ext}"
      end

      attr_reader :chapter_file
      attr_reader :part_file
      attr_reader :bib_file
      attr_reader :reject_file
      attr_reader :predef_file
      attr_reader :postdef_file
      attr_reader :ext
      attr_reader :image_dir
      attr_accessor :image_types
      attr_reader :page_metric

    end
  end
end
