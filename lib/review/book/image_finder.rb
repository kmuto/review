#
# Copyright (c) 2014-2017 Minero Aoki, Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of LGPL, see the file "COPYING".
#

require 'review/extentions'
require 'review/exception'

module ReVIEW
  module Book
    class ImageFinder
      def initialize(basedir, chapid, builder, exts)
        @basedir = basedir
        @chapid = chapid
        @builder = builder
        @exts = exts
        @entries = dir_entries
      end

      def dir_entries
        Dir.glob(File.join(@basedir, '**{,/*/**}/*.*')).uniq
      end

      def add_entry(path)
        @entries << path unless @entries.include?(path)
        @entries
      end

      def find_path(id)
        targets = target_list(id)
        targets.each do |target|
          @exts.each { |ext| return "#{target}#{ext}" if @entries.include?("#{target}#{ext}") }
        end
        nil
      end

      def target_list(id)
        [
          # 1. <basedir>/<builder>/<chapid>/<id>.<ext>
          "#{@basedir}/#{@builder}/#{@chapid}/#{id}",

          # 2. <basedir>/<builder>/<chapid>-<id>.<ext>
          "#{@basedir}/#{@builder}/#{@chapid}-#{id}",

          # 3. <basedir>/<builder>/<id>.<ext>
          "#{@basedir}/#{@builder}/#{id}",

          # 4. <basedir>/<chapid>/<id>.<ext>
          "#{@basedir}/#{@chapid}/#{id}",

          # 5. <basedir>/<chapid>-<id>.<ext>
          "#{@basedir}/#{@chapid}-#{id}",

          # 6. <basedir>/<id>.<ext>
          "#{@basedir}/#{id}"
        ]
      end
    end
  end
end
