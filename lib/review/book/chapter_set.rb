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

    class ChapterSet

      def ChapterSet.for_argv
        if ARGV.empty?
          new([Chapter.for_stdin])
        else
          for_pathes(ARGV)
        end
      end

      def ChapterSet.for_pathes(pathes)
        new(Chapter.intern_pathes(pathes))
      end

      def initialize(chapters)
        @chapters = chapters
      end

      def no_part?
        true
      end

      attr_reader :chapters

      def each_chapter(&block)
        @chapters.each(&block)
      end

      def ext
        '.re'
      end
    end
  end
end
