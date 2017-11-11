# = producer.rb -- EPUB producer.
#
# Copyright (c) 2010-2017 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".

require 'tmpdir'
require 'fileutils'
require 'review/yamlloader'
require 'epubmaker/content'
require 'epubmaker/epubv2'
require 'epubmaker/epubv3'
require 'review/i18n'
require 'review/configure'
require 'review/extentions/hash'

module EPUBMaker
  # EPUBMaker produces EPUB file.
  class Producer
    # Array of content objects.
    attr_accessor :contents
    # Parameter hash.
    attr_accessor :config
    # Message resource object.
    attr_reader :res

    # Take YAML +file+ and return parameter hash.
    def self.load(file)
      raise "Can't open #{file}." if file.nil? || !File.exist?(file)
      loader = ReVIEW::YAMLLoader.new
      loader.load_file(file)
    end

    # Take YAML +file+ and update parameter hash.
    def load(file)
      raise "Can't open #{file}." if file.nil? || !File.exist?(file)
      loader = ReVIEW::YAMLLoader.new
      merge_config(@config.deep_merge(loader.load_file(file)))
    end

    # Construct producer object.
    # +config+ takes initial parameter hash. This parameters can be overriden by EPUBMaker#load or EPUBMaker#merge_config.
    # +version+ takes EPUB version (default is 2).
    def initialize(config = nil, version = nil)
      @contents = []
      @config = ReVIEW::Configure.new
      @epub = nil
      @config['epubversion'] = version unless version.nil?
      @res = ReVIEW::I18n

      merge_config(config) if config
    end

    def coverimage
      return nil unless config['coverimage']
      @contents.each do |item|
        if item.media.start_with?('image') && item.file =~ /#{config['coverimage']}\Z/
          return item.file
        end
      end
      nil
    end

    # Update parameters by merging from new parameter hash +config+.
    def merge_config(config)
      @config.deep_merge!(config)
      complement

      unless @config['epubversion'].nil?
        case @config['epubversion'].to_i
        when 2
          @epub = EPUBMaker::EPUBv2.new(self)
        when 3
          @epub = EPUBMaker::EPUBv3.new(self)
        else
          raise "Invalid EPUB version (#{@config['epubversion']}.)"
        end
      end
      ReVIEW::I18n.locale = config['language'] if config['language']
      support_legacy_maker
    end

    # Write mimetype file to IO object +wobj+.
    def mimetype(wobj)
      s = @epub.mimetype
      wobj.print s if !s.nil? && !wobj.nil?
    end

    # Write opf file to IO object +wobj+.
    def opf(wobj)
      s = @epub.opf
      wobj.puts s if !s.nil? && !wobj.nil?
    end

    # Write ncx file to IO object +wobj+. +indentarray+ defines prefix
    # string for each level.
    def ncx(wobj, indentarray = [])
      s = @epub.ncx(indentarray)
      wobj.puts s if !s.nil? && !wobj.nil?
    end

    # Write container file to IO object +wobj+.
    def container(wobj)
      s = @epub.container
      wobj.puts s if !s.nil? && !wobj.nil?
    end

    # Write cover file to IO object +wobj+.
    # If Producer#config["coverimage"] is defined, it will be used for
    # the cover image.
    def cover(wobj)
      type = @config['epubversion'] >= 3 ? 'cover' : nil
      s = @epub.cover(type)
      wobj.puts s if !s.nil? && !wobj.nil?
    end

    # Write title file (copying) to IO object +wobj+.
    def titlepage(wobj)
      s = @epub.titlepage
      wobj.puts s if !s.nil? && !wobj.nil?
    end

    # Write colophon file to IO object +wobj+.
    def colophon(wobj)
      s = @epub.colophon
      wobj.puts s if !s.nil? && !wobj.nil?
    end

    # Write own toc file to IO object +wobj+.
    def mytoc(wobj)
      s = @epub.mytoc
      wobj.puts s if !s.nil? && !wobj.nil?
    end

    # Add informations of figure files in +path+ to contents array.
    # +base+ defines a string to remove from path name.
    def import_imageinfo(path, base = nil, allow_exts = nil)
      return nil unless File.exist?(path)
      allow_exts = @config['image_ext'] if allow_exts.nil?
      Dir.foreach(path) do |f|
        next if f.start_with?('.')
        if f =~ /\.(#{allow_exts.join('|')})\Z/i
          path.chop! if path =~ %r{/\Z}
          if base.nil?
            @contents.push(EPUBMaker::Content.new('file' => "#{path}/#{f}"))
          else
            @contents.push(EPUBMaker::Content.new('file' => "#{path.sub(base + '/', '')}/#{f}"))
          end
        end
        import_imageinfo("#{path}/#{f}", base) if FileTest.directory?("#{path}/#{f}")
      end
    end

    alias_method :importImageInfo, :import_imageinfo

    # Produce EPUB file +epubfile+.
    # +basedir+ points the directory has contents (default: current directory.)
    # +tmpdir+ defines temporary directory.
    def produce(epubfile, basedir = nil, tmpdir = nil)
      current = Dir.pwd
      basedir = current if basedir.nil?

      new_tmpdir = tmpdir.nil? ? Dir.mktmpdir : tmpdir
      epubfile = "#{current}/#{epubfile}" if epubfile !~ %r{\A/}

      # FIXME: error check
      File.unlink(epubfile) if File.exist?(epubfile)

      begin
        @epub.produce(epubfile, basedir, new_tmpdir)
      ensure
        FileUtils.rm_r(new_tmpdir) if tmpdir.nil?
      end
    end

    def call_hook(filename, *params)
      return if !filename.present? || !File.exist?(filename) || !FileTest.executable?(filename)
      if ENV['REVIEW_SAFE_MODE'].to_i & 1 > 0
        warn 'hook is prohibited in safe mode. ignored.'
      else
        system(filename, *params)
      end
    end

    def isbn_hyphen
      str = @config['isbn'].to_s

      return "#{str[0..0]}-#{str[1..5]}-#{str[6..8]}-#{str[9..9]}" if str =~ /\A\d{10}\Z/
      return "#{str[0..2]}-#{str[3..3]}-#{str[4..8]}-#{str[9..11]}-#{str[12..12]}" if str =~ /\A\d{13}\Z/
      nil
    end

    private

    # Complement parameters.
    def complement
      @config['htmlext'] = 'html' if @config['htmlext'].nil?
      defaults = ReVIEW::Configure.new.merge(
        'language' => 'ja',
        'date' => Time.now.strftime('%Y-%m-%d'),
        'modified' => Time.now.strftime('%Y-%02m-%02dT%02H:%02M:%02SZ'),
        'isbn' => nil,
        'toclevel' => 2,
        'stylesheet' => [],
        'epubversion' => 3,
        'htmlversion' => 5,
        'secnolevel' => 2,
        'pre_secnolevel' => 0,
        'post_secnolevel' => 1,
        'part_secnolevel' => 1,
        'titlepage' => true,
        'titlefile' => nil,
        'originaltitlefile' => nil,
        'profile' => nil,
        'colophon' => nil,
        'colophon_order' => %w[aut csl trl dsr ill edt pbl prt pht],
        'direction' => 'ltr',
        'epubmaker' => {
          'flattoc' => nil,
          'flattocindent' => true,
          'ncx_indent' => [],
          'zip_stage1' => 'zip -0Xq',
          'zip_stage2' => 'zip -Xr9Dq',
          'zip_addpath' => nil,
          'hook_beforeprocess' => nil,
          'hook_afterfrontmatter' => nil,
          'hook_afterbody' => nil,
          'hook_afterbackmatter' => nil,
          'hook_aftercopyimage' => nil,
          'hook_prepack' => nil,
          'rename_for_legacy' => nil,
          'verify_target_images' => nil,
          'force_include_images' => [],
          'cover_linear' => nil
        },
        'externallink' => true,
        'imagedir' => 'images',
        'fontdir' => 'fonts',
        'image_ext' => %w[png gif jpg jpeg svg ttf woff otf],
        'image_maxpixels' => 4_000_000,
        'font_ext' => %w[ttf woff otf]
      )

      @config = defaults.deep_merge(@config)
      @config['title'] = @config['booktitle'] unless @config['title']

      deprecated_parameters = {
        'ncxindent' => 'epubmaker:ncxindent',
        'flattoc' => 'epubmaker:flattoc',
        'flattocindent' => 'epubmaker:flattocindent',
        'hook_beforeprocess' => 'epubmaker:hook_beforeprocess',
        'hook_afterfrontmatter' => 'epubmaker:hook_afterfrontmatter',
        'hook_afterbody' => 'epubmaker:hook_afterbody',
        'hook_afterbackmatter' => 'epubmaker:hook_afterbackmatter',
        'hook_aftercopyimage' => 'epubmaker:hook_aftercopyimage',
        'hook_prepack' => 'epubmaker:hook_prepack',
        'rename_for_legacy' => 'epubmaker:rename_for_legacy',
        'zip_stage1' => 'epubmaker:zip_stage1',
        'zip_stage2' => 'epubmaker:zip_stage2',
        'zip_addpath' => 'epubmaker:zip_addpath',
        'verify_target_images' => 'epubmaker:verify_target_images',
        'force_include_images' => 'epubmaker:force_include_images',
        'cover_linear' => 'epubmaker:cover_linear'
      }

      deprecated_parameters.each_pair do |k, v|
        next if @config[k].nil?
        sa = v.split(':', 2)
        warn "Parameter #{k} is deprecated. Use:\n#{sa[0]}:\n  #{sa[1]}: ...\n\n"
        @config[sa[0]][sa[1]] = @config[k]
        @config.delete(k)
      end

      @config['htmlversion'] = 5 if @config['epubversion'] >= 3

      @config.maker = 'epubmaker'
      @config['cover'] = "#{@config['bookname']}.#{@config['htmlext']}" unless @config['cover']

      %w[bookname title].each do |k|
        raise "Key #{k} must have a value. Abort." unless @config[k]
      end
      # array
      %w[subject aut
         a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-dsr a-edt
         a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl
         adp ann arr art asn aut aqt aft aui ant bkp clb cmm dsr edt
         ill lyr mdc mus nrt oth pht pbl prt red rev spn ths trc trl
         stylesheet rights].each do |item|
        next unless @config[item]
        @config[item] = [@config[item]] if @config[item].is_a?(String)
      end
      # optional
      # type, format, identifier, source, relation, coverpage, aut
    end

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

      true
    end
  end
end
