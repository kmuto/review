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
require 'review/configure'
require 'review/catalog'

module ReVIEW
  module Book
    class Base

      attr_writer :config

      def self.load_default
        warn 'Book::Base.load_default() is obsoleted. Use Book::Base.load().'
        load()
      end

      def self.load(dir = ".")
        update_rubyenv dir
        new(dir)
      end

      @basedir_seen = {}

      def self.update_rubyenv(dir)
        return if @basedir_seen.key?(dir)
        if File.file?("#{dir}/review-ext.rb")
          if ENV["REVIEW_SAFE_MODE"].to_i & 2 > 0
            warn "review-ext.rb is prohibited in safe mode. ignored."
          else
            Kernel.load File.expand_path("#{dir}/review-ext.rb")
          end
        end
        @basedir_seen[dir] = true
      end

      def initialize(basedir)
        @basedir = basedir
        @parts = nil
        @chapter_index = nil
        @config = ReVIEW::Configure.values
        @catalog = nil
      end

      def bib_file
        config["bib_file"]
      end

      def reject_file
        config["reject_file"]
      end

      def ext
        config["ext"]
      end

      def image_dir
        config["image_dir"]
      end

      def image_types
        config["image_types"]
      end

      def image_types=(types)
        config["image_types"] = types
      end

      def page_metric
        if config["page_metric"].respond_to?(:downcase) && config["page_metric"].upcase =~ /^[A-Z0-9_]+$/
          ReVIEW::Book::PageMetric.const_get(config["page_metric"].upcase)
        elsif config["page_metric"].kind_of?(Array) && config["page_metric"].size == 5
          ReVIEW::Book::PageMetric.new(*config["page_metric"])
        else
          config["page_metric"]
        end
      end

      def parts
        @parts ||= read_parts()
      end

      def parts_in_file
        parts.find_all{|part|
          part if part.present? and part.file?
        }
      end

      def part(n)
        parts.detect {|part| part.number == n }
      end

      def each_part(&block)
        parts.each(&block)
      end

      def chapters
        parts().map {|p| p.chapters }.flatten
      end

      def each_chapter(&block)
        chapters.each(&block)
      end

      def each_chapter_r(&block)
        chapters.reverse.each(&block)
      end

      def chapter_index
        return @chapter_index if @chapter_index

        contents = chapters()
        parts().each do |prt|
          if prt.id.present?
            contents << prt
          end
        end
        @chapter_index = ChapterIndex.new(contents)
      end

      def chapter(id)
        chapter_index()[id]
      end

      def next_chapter(chapter)
        finded = false
        each_chapter do |c|
          return c if finded
          finded = true if c == chapter
        end
        nil # not found
      end

      def prev_chapter(chapter)
        finded = false
        each_chapter_r do |c|
          return c if finded
          finded = true if c == chapter
        end
        nil # not found
      end

      def volume
        vol = Volume.sum(chapters.map {|chap| chap.volume })
        vol.page_per_kbyte = page_metric.page_per_kbyte
        vol
      end

      def config
        @config ||= Configure.values
      end

      # backward compatible
      def param=(param)
        @config = param
      end

      def load_config(filename)
        new_conf = YAML.load_file(filename)
        @config.merge!(new_conf)
      end

      # backward compatible
      def param
        @config
      end

      def catalog
        return @catalog if @catalog.present?

        catalogfile_path = "#{basedir}/#{config["catalogfile"]}"
        if File.file? catalogfile_path
          @catalog = Catalog.new(File.open catalogfile_path)
        end

        @catalog
      end

      def read_CHAPS
        if catalog
          catalog.chaps
        else
          read_FILE(config["chapter_file"])
        end
      end

      def read_PREDEF
        if catalog
          catalog.predef
        else
          read_FILE(config["predef_file"])
        end
      end

      def read_APPENDIX
        if catalog
          catalog.appendix
        else
          read_FILE(config["postdef_file"]) # for backward compatibility
        end
      end

      def read_POSTDEF
        if catalog
          catalog.postdef
        else
          ""
        end
      end

      def read_PART
        return @read_PART if @read_PART

        if catalog
          @read_PART = catalog.parts
        else
          @read_PART = File.read("#{@basedir}/#{config["part_file"]}")
        end
      end

      def part_exist?
        if catalog
          catalog.parts.present?
        else
          File.exist?("#{@basedir}/#{config["part_file"]}")
        end
      end

      def read_bib
        File.read("#{@basedir}/#{bib_file}")
      end

      def bib_exist?
        File.exist?("#{@basedir}/#{bib_file}")
      end

      def prefaces
        if catalog
          return mkpart_from_namelist(catalog.predef.split("\n"))
        end

        if File.file?("#{@basedir}/#{config["predef_file"]}")
          begin
            return mkpart_from_namelistfile("#{@basedir}/#{config["predef_file"]}")
          rescue FileNotFound => err
            raise FileNotFound, "preface #{err.message}"
          end
        end
      end

      def appendix
        if catalog
          names = catalog.appendix.split("\n")
          chaps = names.each_with_index.map {|n, idx|
            mkchap_ifexist(n, idx)
          }.compact
          return mkpart(chaps)
        end

        if File.file?("#{@basedir}/#{config["postdef_file"]}")
          begin
            return mkpart_from_namelistfile("#{@basedir}/#{config["postdef_file"]}")
          rescue FileNotFound => err
            raise FileNotFound, "postscript #{err.message}"
          end
        end
      end

      def postscripts
        if catalog
          mkpart_from_namelist(catalog.postdef.split("\n"))
        end
      end

      def basedir
        @basedir
      end

      private

      def read_parts
        list = parse_chapters
        if pre = prefaces
          list.unshift pre
        end
        if app = appendix
          list.push app
        end
        if post = postscripts
          list.push post
        end
        list
      end

      def parse_chapters
        part = 0
        num = 0

        if catalog
          return catalog.parts_with_chaps.map do |entry|
            if entry.is_a? Hash
              chaps = entry.values.first.map do |chap|
                Chapter.new(self, (num += 1), chap, "#{@basedir}/#{chap}")
              end
              Part.new(self, (part += 1), chaps, read_PART.split("\n")[part - 1])
            else
              chap = Chapter.new(self, (num += 1), entry, "#{@basedir}/#{entry}")
              Part.new(self, nil, [chap])
            end
          end
        end

        chap = read_CHAPS()\
          .strip.lines.map {|line| line.strip }.join("\n").split(/\n{2,}/)\
          .map {|part_chunk|
          chaps = part_chunk.split.map {|chapid|
            Chapter.new(self, (num += 1), chapid, "#{@basedir}/#{chapid}")
          }
          if part_exist? && read_PART.split("\n").size >= part
            Part.new(self, (part += 1), chaps, read_PART.split("\n")[part-1])
          else
            Part.new(self, (part += 1), chaps)
          end
        }
        return chap
      end

      def mkpart_from_namelistfile(path)
        chaps = []
        File.read(path).split.each_with_index do |name, idx|
          name.sub!(/\A\xEF\xBB\xBF/u, '') # remove BOM
          if path =~ /PREDEF/
            chaps << mkchap(name)
          else
            chaps << mkchap(name, idx + 1)
          end
        end
        mkpart(chaps)
      end

      def mkpart_from_namelist(names)
        mkpart(names.map {|n| mkchap_ifexist(n) }.compact)
      end

      def mkpart(chaps)
        chaps.empty? ? nil : Part.new(self, nil, chaps)
      end

      def mkchap(name, number = nil)
        name += ext if File.extname(name) == ""
        path = "#{@basedir}/#{name}"
        raise FileNotFound, "file not exist: #{path}" unless File.file?(path)
        Chapter.new(self, number, name, path)
      end

      def mkchap_ifexist(name, idx = nil)
        name += ext if File.extname(name) == ""
        path = "#{@basedir}/#{name}"
        if File.file?(path)
          idx += 1 if idx
          Chapter.new(self, idx, name, path)
        end
      end

      def read_FILE(filename)
        res = ""
        File.open("#{@basedir}/#{filename}") do |f|
          while line = f.gets
            line.sub!(/\A\xEF\xBB\xBF/u, '') # remove BOM
            if /\A#/ =~ line
              next
            end
            line.gsub!(/#.*$/, "")
            res << line
          end
        end
        res
      rescue Errno::ENOENT
        Dir.glob("#{@basedir}/*#{ext()}").sort.join("\n")
      rescue Errno::EISDIR
        ""
      end
    end
  end
end
