#
# Copyright (c) 2009-2022 Minero Aoki, Kenshi Muto, Masayoshi Takahashi
#               2002-2008 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
require 'review/configure'
require 'review/catalog'
require 'review/book/bib'

module ReVIEW
  module Book
    class Base
      attr_accessor :config
      attr_writer :parts
      attr_accessor :catalog
      attr_reader :basedir
      attr_accessor :bibpaper_index

      def self.load(basedir = '.', config: nil)
        new(basedir, config: config)
      end

      def initialize(basedir = '.', config: nil)
        @basedir = basedir
        @logger = ReVIEW.logger
        @parts = nil
        @chapter_index = nil
        @config = config || ReVIEW::Configure.values
        @catalog = nil
        @bibpaper_index = nil
        catalog_path = filename_join(@basedir, @config['catalogfile'])
        if catalog_path && File.file?(catalog_path)
          parse_catalog_file(catalog_path)
        end

        @warn_old_files = {} # XXX for checking CHAPS, PREDEF, POSTDEF
        @basedir_seen = {}
        update_rubyenv
      end

      def update_rubyenv
        if File.file?(File.join(@basedir, 'review-ext.rb'))
          if ENV['REVIEW_SAFE_MODE'].to_i & 2 > 0
            @logger.warn 'review-ext.rb is prohibited in safe mode. ignored.'
          else
            Kernel.load(File.expand_path(File.join(@basedir, 'review-ext.rb')))
          end
        end
      end

      def execute_indexer
        return unless @catalog

        parts.each do |part|
          part.chapters.each(&:execute_indexer)
        end
      end

      def bib_file
        config['bib_file']
      end

      def reject_file
        config['reject_file']
      end

      def ext
        config['ext']
      end

      def imagedir
        File.join(@basedir, config['imagedir'])
      end

      def image_types
        config['image_types']
      end

      def image_types=(types)
        config['image_types'] = types
      end

      def contentdir
        if !config['contentdir'].present? || config['contentdir'] == '.'
          @basedir
        else
          File.join(@basedir, config['contentdir'])
        end
      end

      def page_metric
        if config['page_metric'].respond_to?(:downcase) && config['page_metric'].upcase =~ /\A[A-Z0-9_]+\Z/
          ReVIEW::Book::PageMetric.const_get(config['page_metric'].upcase)
        elsif config['page_metric'].is_a?(Array) && (config['page_metric'].size == 5 || config['page_metric'].size == 4)
          ReVIEW::Book::PageMetric.new(*config['page_metric'])
        else
          config['page_metric']
        end
      end

      def htmlversion
        if config['htmlversion'].blank?
          nil
        else
          config['htmlversion'].to_i
        end
      end

      def create_chapter_index
        chapter_index = ChapterIndex.new
        each_chapter do |chap|
          chapter_index.add_item(Index::Item.new(chap.id, chap.number, chap))
        end
        parts.each do |prt|
          if prt.id.present?
            chapter_index.add_item(Index::Item.new(prt.id, prt.number, prt))
          end
        end
        chapter_index
      end

      def generate_indexes
        if bib_exist?
          bib = ReVIEW::Book::Bib.new(file_content: bib_content, book: self)
          bib.generate_indexes(use_bib: true)
          @bibpaper_index = bib.bibpaper_index
        end
        self.each_chapter(&:generate_indexes)
        self.parts.map(&:generate_indexes)
        @chapter_index = create_chapter_index
      end

      def parts
        @parts ||= read_parts
      end

      def parts_in_file
        # TODO: should be `parts.find_all{|part| part.present? and part.file?}` ?
        parts.find_all do |part|
          part if part.present? && part.file?
        end
      end

      def part(n)
        parts.detect { |part| part.number == n }
      end

      def each_part(&block)
        parts.each(&block)
      end

      def contents
        # TODO: includes predef, appendix, postdef
        if parts.present?
          chapters + parts
        else
          chapters
        end
      end

      def chapters
        parts.map(&:chapters).flatten
      end

      def each_chapter(&block)
        chapters.each(&block)
      end

      def each_chapter_r(&block)
        chapters.reverse_each(&block)
      end

      def chapter_index
        return @chapter_index if @chapter_index

        @chapter_index = create_chapter_index
        @chapter_index
      end

      def chapter(id)
        chapter_index[id].content
      end

      def next_chapter(chapter)
        finded = false
        each_chapter do |c|
          return c if finded

          if c == chapter
            finded = true
          end
        end
        nil # not found
      end

      def prev_chapter(chapter)
        finded = false
        each_chapter_r do |c|
          return c if finded

          if c == chapter
            finded = true
          end
        end
        nil # not found
      end

      def volume
        Volume.sum(parts.map(&:volume) + chapters.map(&:volume))
      end

      def load_config(filename)
        new_conf = YAML.review_load_file(filename, aliases: true, permitted_classes: [Date])
        @config.merge!(new_conf)
      end

      def parse_catalog_file(path)
        unless File.file?(path)
          raise FileNotFound, "catalog.yml is not found #{path}"
        end

        File.open(path, 'rt:BOM|utf-8') do |f|
          @catalog = Catalog.new(f)
          @catalog.validate!(@config, basedir)
        end
      end

      def read_chaps
        if catalog
          catalog.chaps
        else
          read_file(config['chapter_file']).split("\n")
        end
      end

      def read_predef
        if catalog
          catalog.predef
        else
          read_file(config['predef_file']).split("\n")
        end
      end

      def read_appendix
        if catalog
          catalog.appendix
        else
          read_file(config['postdef_file']).split("\n") # for backward compatibility
        end
      end

      def read_postdef
        if catalog
          catalog.postdef
        else
          []
        end
      end

      def read_part
        if catalog
          catalog.parts
        else
          File.read(File.join(@basedir, config['part_file'])).split("\n")
        end
      end

      def part_exist?
        if catalog
          catalog.parts.present?
        else
          File.exist?(File.join(@basedir, config['part_file']))
        end
      end

      def read_bib
        File.read(File.join(contentdir, bib_file))
      end

      def bib_exist?
        File.exist?(File.join(contentdir, bib_file))
      end

      def bib_content
        File.read(File.join(contentdir, bib_file))
      end

      def prefaces
        if catalog
          return Part.mkpart_from_namelist(self, catalog.predef)
        end

        begin
          predef_file = filename_join(@basedir, config['predef_file'])
          if File.file?(predef_file)
            Part.mkpart_from_namelistfile(self, predef_file)
          end
        rescue FileNotFound => e
          raise FileNotFound, "preface #{e.message}"
        end
      end

      def appendix
        if catalog
          names = catalog.appendix
          chaps = names.each_with_index.map { |name, number| Chapter.mkchap_ifexist(self, name, number + 1) }.compact
          return Part.mkpart(chaps)
        end

        begin
          postdef_file = filename_join(@basedir, config['postdef_file'])
          if File.file?(postdef_file)
            Part.mkpart_from_namelistfile(self, postdef_file)
          end
        rescue FileNotFound => e
          raise FileNotFound, "postscript #{e.message}"
        end
      end

      def postscripts
        if catalog
          Part.mkpart_from_namelist(self, catalog.postdef)
        end
      end

      private

      def read_parts
        list = parse_chapters
        # NOTE: keep this = style to work this logic.
        if pre = prefaces
          list.unshift(pre)
        end
        if app = appendix
          list.push(app)
        end
        if post = postscripts
          list.push(post)
        end
        list
      end

      # return Array of Part, not Chapter
      #
      def parse_chapters
        part = 0
        num = 0

        if catalog
          return catalog.parts_with_chaps.map do |entry|
            if entry.is_a?(Hash)
              chaps = entry.values.first.map do |chap|
                chap = Chapter.new(self, num += 1, chap, File.join(contentdir, chap))
                chap
              end
              Part.new(self, part += 1, chaps, read_part[part - 1])
            else
              chap = Chapter.new(self, num += 1, entry, File.join(contentdir, entry))
              if chap.number
                num = chap.number
              else
                num -= 1
              end
              Part.new(self, nil, [chap])
            end
          end
        end

        # rubocop:disable Style/RedundantAssignment
        chap = read_chaps.map(&:strip).join("\n").split(/\n{2,}/).map do |part_chunk|
          chaps = part_chunk.split.map { |chapid| Chapter.new(self, num += 1, chapid, File.join(contentdir, chapid)) }
          if part_exist? && read_part.size > part
            Part.new(self, part += 1, chaps, read_part[part - 1])
          else
            Part.new(self, nil, chaps)
          end
        end
        # rubocop:enable Style/RedundantAssignment

        chap
      end

      def read_file(filename)
        unless @warn_old_files[filename]
          @warn_old_files[filename] = true
          if caller.none? { |item| item =~ %r{/review/test/test_} }
            @logger.warn "!!! #{filename} is obsoleted. please use catalog.yml."
          end
        end
        res = ''
        File.open(filename_join(@basedir, filename), 'rt:BOM|utf-8') do |f|
          f.each_line do |line|
            next if line.start_with?('#')

            line.gsub!(/#.*\Z/, '')
            res << line
          end
        end
        res
      rescue Errno::ENOENT
        Dir.glob("#{@basedir}/*#{ext}").sort.join("\n")
      rescue Errno::EISDIR
        ''
      end

      def filename_join(*args)
        File.join(args.compact)
      end
    end
  end
end
