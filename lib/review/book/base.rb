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
    class Base

      attr_accessor :param

      def self.load_default
        %w( . .. ../.. ).each do |basedir|
          if File.file?("#{basedir}/CHAPS")
            book = load(basedir)
            if File.file?("#{basedir}/config.rb")
              book.instance_variable_set("@parameters", Parameters.load("#{basedir}/config.rb"))
            end
            return book
          end
        end
        new('.')
      end

      def self.load(dir)
        update_rubyenv dir
        new(dir)
      end

      @basedir_seen = {}

      def self.update_rubyenv(dir)
        return if @basedir_seen.key?(dir)
        if File.directory?("#{dir}/lib/review")
          $LOAD_PATH.unshift "#{dir}/lib"
        end
        if File.file?("#{dir}/review-ext.rb")
          Kernel.load File.expand_path("#{dir}/review-ext.rb")
        end
        @basedir_seen[dir] = true
      end

      def initialize(basedir, parameters = Parameters.default)
        @basedir = basedir
        @parameters = parameters
        @parts = nil
        @chapter_index = nil
      end

      extend Forwardable
      def_delegators '@parameters',
      :chapter_file,
      :part_file,
      :bib_file,
      :reject_file,
      :predef_file,
      :postdef_file,
      :ext,
      :image_dir,
      :image_types,
      :page_metric

      def parts
        @parts ||= read_parts()
      end

      def parts_in_file
        parts.find_all{|part| part if part.file? }
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

      def chapter_index
        @chapter_index ||= ChapterIndex.new(chapters())
        @chapter_index
      end

      def chapter(id)
        chapter_index()[id]
      end

      def volume
        Volume.sum(chapters.map {|chap| chap.volume })
      end

      def read_CHAPS
        res = ""
        File.open("#{@basedir}/#{chapter_file}") do |f|
          while line = f.gets
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
      end

      def read_PART
        @read_PART ||= File.read("#{@basedir}/#{part_file}")
      end

      def part_exist?
        File.exist?("#{@basedir}/#{part_file}")
      end

      def read_bib
        File.read("#{@basedir}/#{bib_file}")
      end

      def bib_exist?
        File.exist?("#{@basedir}/#{bib_file}")
      end

      def prefaces
        if File.file?("#{@basedir}/#{predef_file}")
          begin
            return mkpart_from_namelistfile("#{@basedir}/#{predef_file}")
          rescue FileNotFound => err
            raise FileNotFound, "preface #{err.message}"
          end
        else
          mkpart_from_namelist(%w(preface))
        end
      end

      def postscripts
        if File.file?("#{@basedir}/#{postdef_file}")
          begin
            return mkpart_from_namelistfile("#{@basedir}/#{postdef_file}")
          rescue FileNotFound => err
            raise FileNotFound, "postscript #{err.message}"
          end
        else
          mkpart_from_namelist(%w(appendix postscript))
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
        if post = postscripts
          list.push post
        end
        list
      end

      def parse_chapters
        part = 0
        num = 0
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
        mkpart(File.read(path).split.map {|name| mkchap(name) })
      end

      def mkpart_from_namelist(names)
        mkpart(names.map {|n| mkchap_ifexist(n) }.compact)
      end

      def mkpart(chaps)
        chaps.empty? ? nil : Part.new(self, nil, chaps)
      end

      def mkchap(name)
        name += ext if File.extname(name) == ""
        path = "#{@basedir}/#{name}"
        raise FileNotFound, "file not exist: #{path}" unless File.file?(path)
        Chapter.new(self, nil, name, path)
      end

      def mkchap_ifexist(id)
        name = "#{id}#{ext()}"
        path = "#{@basedir}/#{name}"
        File.file?(path) ? Chapter.new(self, nil, name, path) : nil
      end

    end
  end
end
