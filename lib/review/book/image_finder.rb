# frozen_string_literal: true

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
        @paths = dir_entries
        @entries_by_basename = @book.cache.fetch(:image_finder_entries_by_basename) do
          build_entries.group_by { |entry| entry[:basename] }
        end
      end

      def entry_object(path)
        { path: path, basename: path.sub(/\.[^.]+$/, ''), downcase: path.sub(/\.[^.]+$/, $&.downcase) }
      end

      def dir_entries
        @book.cache.fetch(:image_finder_dir_entries) do
          Dir.glob(File.join(@basedir, '**{,/*/**}/*.*')).uniq.sort.map { |entry| entry.sub(%r{^\./}, '') }
        end
      end

      def add_entry(path)
        path.sub!(%r{^\./}, '')
        unless @entries
          # Generated images belong to this finder. Keep the book's index intact.
          @entries = build_entries
          @entries_by_basename = @entries.group_by { |entry| entry[:basename] }
        end
        entry = entry_object(path)
        candidates = (@entries_by_basename[entry[:basename]] ||= [])
        unless candidates.any? { |candidate| candidate[:path] == path }
          candidates << entry
          @entries << entry
        end
        @entries
      end

      def find_path(id)
        target_list(id).each do |target|
          candidates = @entries_by_basename[target]
          next unless candidates

          @book.image_types.each do |ext|
            name = "#{target}#{ext}"
            entry = candidates.find { |candidate| candidate[:downcase] == name }
            return entry[:path] if entry
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

      private

      def build_entries
        @paths.map { |path| entry_object(path) }
      end
    end
  end
end
