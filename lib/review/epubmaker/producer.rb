# frozen_string_literal: true

# = producer.rb -- EPUB producer.
#
# Copyright (c) 2010-2023 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
# == Quick usage
#  require 'review/epubmaker'
#  producer = ReVIEW::EPUBMaker::Producer.new(config)
#  producer.contents.push(ReVIEW::EPUBMaker::Content.new(file: 'ch01.xhtml'))
#  producer.contents.push(ReVIEW::EPUBMaker::Content.new(file: 'ch02.xhtml'))
#   ...
#  producer.import_imageinfo('images')
#  producer.produce(epub_filename)

require 'tmpdir'
require 'fileutils'
require 'review/yamlloader'
require 'review/epubmaker/content'
require 'review/epubmaker/epubv2'
require 'review/epubmaker/epubv3'
require 'review/i18n'
require 'review/configure'
require 'review/extentions/hash'
require 'review/loggable'

module ReVIEW
  class EPUBMaker
    # EPUBMaker produces EPUB file.
    class Producer
      include Loggable

      # Array of content objects.
      attr_accessor :contents
      # Parameter hash.
      attr_accessor :config
      # Message resource object.
      attr_reader :res

      # Construct producer object.
      # +config+ takes initial parameter hash.
      def initialize(config)
        @contents = []
        @config = config
        @config.maker = 'epubmaker'
        @epub = nil
        @res = ReVIEW::I18n
        @logger = ReVIEW.logger
        modify_config
      end

      # Modify parameters for EPUB specific.
      def modify_config
        if @config['epubversion'] >= 3
          @config['htmlversion'] = 5
        end

        @config['title'] ||= @config['booktitle']
        @config['cover'] ||= "#{@config['bookname']}.#{@config['htmlext']}"

        %w[bookname title].each do |k|
          unless @config[k]
            raise "Key #{k} must have a value. Abort."
          end
        end

        case @config['epubversion'].to_i
        when 2
          @epub = ReVIEW::EPUBMaker::EPUBv2.new(self)
        when 3
          @epub = ReVIEW::EPUBMaker::EPUBv3.new(self)
        else
          raise "Invalid EPUB version (#{@config['epubversion']}.)"
        end

        ReVIEW::I18n.locale = @config['language']
        support_legacy_maker
      end

      # Add informations of figure files in +path+ to contents array.
      # +base+ defines a string to remove from path name.
      def import_imageinfo(path, base = nil, allow_exts = nil)
        return nil unless File.exist?(path)

        allow_exts ||= @config['image_ext']
        Dir.foreach(path) do |f|
          next if f.start_with?('.')

          if /\.(#{allow_exts.join('|')})\Z/i.match?(f)
            path.chop! if %r{/\Z}.match?(path)
            if base.nil?
              @contents.push(ReVIEW::EPUBMaker::Content.new(file: "#{path}/#{f}"))
            else
              @contents.push(ReVIEW::EPUBMaker::Content.new(file: "#{path.sub(base + '/', '')}/#{f}"))
            end
          end
          if FileTest.directory?("#{path}/#{f}")
            import_imageinfo("#{path}/#{f}", base)
          end
        end
      end

      alias_method :importImageInfo, :import_imageinfo

      # Produce EPUB file +epubfile+.
      # +work_dir+ points the directory has contents (default: current directory.)
      # +tmpdir+ defines temporary directory.
      # +base_dir+ is original root dir.
      def produce(epubfile, work_dir, tmpdir = nil, base_dir: nil)
        current = Dir.pwd
        base_dir ||= current

        # use Dir to solve a path for Windows (see #1011)
        new_tmpdir = Dir[File.join(tmpdir.nil? ? Dir.mktmpdir : tmpdir)][0]
        unless epubfile.start_with?('/')
          epubfile = "#{current}/#{epubfile}"
        end

        FileUtils.rm_f(epubfile)

        begin
          @epub.produce(epubfile, work_dir, new_tmpdir, base_dir: base_dir)
        ensure
          FileUtils.rm_r(new_tmpdir) if tmpdir.nil?
        end
      end

      private

      def support_legacy_maker
        # legacy review-epubmaker support
        if @config['flag_legacy_coverfile'].nil? && !@config['coverfile'].nil? && File.exist?(@config['coverfile'])
          @config['cover'] = "#{@config['bookname']}-cover.#{@config['htmlext']}"
          @epub.legacy_cover_and_title_file(@config['coverfile'], @config['cover'])
          @config['flag_legacy_coverfile'] = true
          warn %Q(Parameter 'coverfile' is obsolete. Please use 'cover' and make complete html file with header and footer.)
        end

        if @config['flag_legacy_titlepagefile'].nil? && !@config['titlepagefile'].nil? && File.exist?(@config['titlepagefile'])
          @config['titlefile'] = "#{@config['bookname']}-title.#{@config['htmlext']}"
          @config['titlepage'] = true
          @epub.legacy_cover_and_title_file(@config['titlepagefile'], @config['titlefile'])
          @config['flag_legacy_titlepagefile'] = true
          warn %Q(Parameter 'titlepagefile' is obsolete. Please use 'titlefile' and make complete html file with header and footer.)
        end

        if @config['flag_legacy_backcoverfile'].nil? && !@config['backcoverfile'].nil? && File.exist?(@config['backcoverfile'])
          @config['backcover'] = "#{@config['bookname']}-backcover.#{@config['htmlext']}"
          @epub.legacy_cover_and_title_file(@config['backcoverfile'], @config['backcover'])
          @config['flag_legacy_backcoverfile'] = true
          warn %Q(Parameter 'backcoverfile' is obsolete. Please use 'backcover' and make complete html file with header and footer.)
        end

        if @config['flag_legacy_pubhistory'].nil? && @config['pubhistory']
          @config['history'] = [[]]
          @config['pubhistory'].split("\n").each { |date| @config['history'][0].push(date.sub(/(\d+)年(\d+)月(\d+)日/, '\1-\2-\3')) }
          @config['flag_legacy_pubhistory'] = true
          warn %Q(Parameter 'pubhistory' is obsolete. Please use 'history' array.)
        end
      end
    end
  end
end
