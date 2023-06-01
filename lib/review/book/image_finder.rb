#
# Copyright (c) 2014-2023 Minero Aoki, Kenshi Muto, Masayoshi Takahashi
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
      def initialize(chapter)
        @book = chapter.book
        @basedir = @book.imagedir
        @chapid = chapter.id
        @builder = @book.config['builder']
        @entries = dir_entries.map { |path| entry_object(path) }
      end

      def entry_object(path)
        { path: path, basename: path.sub(/\.[^.]+$/, ''), downcase: path.sub(/\.[^.]+$/, $&.downcase) }
      end

      def dir_entries
        Dir.glob(File.join(@basedir, '**{,/*/**}/*.*')).uniq.sort.map { |entry| entry.sub(%r{^\./}, '') }
      end

      def add_entry(path)
        path.sub!(%r{^\./}, '')
        unless @entries.find { |entry| entry[:path] == path }
          @entries << entry_object(path)
        end
        @entries
      end

      def find_path(id)
        targets = target_list(id)
        targets.each do |target|
          @book.image_types.each do |ext|
            entries = @entries.select do |entry|
              entry[:basename] == target
            end

            unless entries
              break
            end

            entries.find do |entry|
              if entry[:downcase] == "#{target}#{ext}"
                return entry[:path]
              end
            end
          end
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
