# encoding: utf-8
# = producer.rb -- EPUB producer.
#
# Copyright (c) 2010-2016 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".

require 'tmpdir'
require 'fileutils'
require 'review/yamlloader'
require 'securerandom'
require 'epubmaker/content'
require 'epubmaker/epubv2'
require 'epubmaker/epubv3'
require 'review/i18n'
require 'review/extentions/hash'

module EPUBMaker
  # EPUBMaker produces EPUB file.
  class Producer
    # Array of content objects.
    attr_accessor :contents
    # Parameter hash.
    attr_accessor :params
    # Message resource object.
    attr_reader :res

    # Take YAML +file+ and return parameter hash.
    def Producer.load(file)
      raise "Can't open #{file}." if file.nil? || !File.exist?(file)
      loader = ReVIEW::YAMLLoader.new
      loader.load_file(file)
    end

    # Take YAML +file+ and update parameter hash.
    def load(file)
      raise "Can't open #{file}." if file.nil? || !File.exist?(file)
      loader = ReVIEW::YAMLLoader.new
      merge_params(@params.deep_merge(loader.load_file(file)))
    end

    # Construct producer object.
    # +params+ takes initial parameter hash. This parameters can be overriden by EPUBMaker#load or EPUBMaker#merge_params.
    # +version+ takes EPUB version (default is 2).
    def initialize(params=nil, version=nil)
      @contents = []
      @params = ReVIEW::Configure.new
      @epub = nil
      @params["epubversion"] = version unless version.nil?
      @res = ReVIEW::I18n

      if params
        merge_params(params)
      end
    end

    def coverimage
      return nil unless params["coverimage"]
      @contents.each do |item|
        if item.media.start_with?('image') && item.file =~ /#{params["coverimage"]}\Z/ # /
          return item.file
        end
      end
      return nil
    end

    # Update parameters by merging from new parameter hash +params+.
    def merge_params(params)
      @params = @params.deep_merge(params)
      complement

      unless @params["epubversion"].nil?
        case @params["epubversion"].to_i
        when 2
          @epub = EPUBMaker::EPUBv2.new(self)
        when 3
          @epub = EPUBMaker::EPUBv3.new(self)
        else
          raise "Invalid EPUB version (#{@params["epubversion"]}.)"
        end
      end
      if params["language"]
        ReVIEW::I18n.locale = params["language"]
      end
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
    def ncx(wobj, indentarray=[])
      s = @epub.ncx(indentarray)
      wobj.puts s if !s.nil? && !wobj.nil?
    end

    # Write container file to IO object +wobj+.
    def container(wobj)
      s = @epub.container
      wobj.puts s if !s.nil? && !wobj.nil?
    end

    # Write cover file to IO object +wobj+.
    # If Producer#params["coverimage"] is defined, it will be used for
    # the cover image.
    def cover(wobj)
      type = (@params["epubversion"] >= 3) ? "cover" : nil
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
    def import_imageinfo(path, base=nil, allow_exts=nil)
      return nil unless File.exist?(path)
      allow_exts = @params["image_ext"] if allow_exts.nil?
      Dir.foreach(path) do |f|
        next if f.start_with?('.')
        if f =~ /\.(#{allow_exts.join("|")})\Z/i
          path.chop! if path =~ /\/\Z/
          if base.nil?
            @contents.push(EPUBMaker::Content.new({"file" => "#{path}/#{f}"}))
          else
            @contents.push(EPUBMaker::Content.new({"file" => "#{path.sub(base + "/", '')}/#{f}"}))
          end
        end
        if FileTest.directory?("#{path}/#{f}")
          import_imageinfo("#{path}/#{f}", base)
        end
      end
    end

    alias_method :importImageInfo, :import_imageinfo

    # Produce EPUB file +epubfile+.
    # +basedir+ points the directory has contents (default: current directory.)
    # +tmpdir+ defines temporary directory.
    def produce(epubfile, basedir=nil, tmpdir=nil)
      current = Dir.pwd
      basedir = current if basedir.nil?

      _tmpdir = tmpdir.nil? ? Dir.mktmpdir : tmpdir
      epubfile = "#{current}/#{epubfile}" if epubfile !~ /\A\// # /

      # FIXME: error check
      File.unlink(epubfile) if File.exist?(epubfile)

      begin
        @epub.produce(epubfile, basedir, _tmpdir)
      ensure
        FileUtils.rm_r(_tmpdir) if tmpdir.nil?
      end
    end

    def call_hook(filename, *params)
      if !filename.nil? && File.exist?(filename) && FileTest.executable?(filename)
        if ENV["REVIEW_SAFE_MODE"].to_i & 1 > 0
          warn "hook is prohibited in safe mode. ignored."
        else
          system(filename, *params)
        end
      end
    end

    def isbn_hyphen
      str = @params["isbn"].to_s

      if str =~ /\A\d{10}\Z/
        "#{str[0..0]}-#{str[1..5]}-#{str[6..8]}-#{str[9..9]}"
      elsif str =~ /\A\d{13}\Z/
        "#{str[0..2]}-#{str[3..3]}-#{str[4..8]}-#{str[9..11]}-#{str[12..12]}"
      else
        nil
      end
    end

    private

    # Complement parameters.
    def complement
      @params["htmlext"] = "html" if @params["htmlext"].nil?
      defaults = ReVIEW::Configure.new.merge({
        "cover" => "#{@params["bookname"]}.#{@params["htmlext"]}",
        "language" => "ja",
        "date" => Time.now.strftime("%Y-%m-%d"),
        "modified" => Time.now.strftime("%Y-%02m-%02dT%02H:%02M:%02SZ"),
        "urnid" => "urn:uid:#{SecureRandom.uuid}",
        "isbn" => nil,
        "toclevel" => 2,
        "stylesheet" => [],
        "epubversion" => 3,
        "htmlversion" => 5,
        "secnolevel" => 2,
        "pre_secnolevel" => 0,
        "post_secnolevel" => 1,
        "part_secnolevel" => 1,
        "titlepage" => nil,
        "titlefile" => nil,
        "originaltitlefile" => nil,
        "profile" => nil,
        "colophon" => nil,
        "colophon_order" => %w[aut csl trl dsr ill edt pbl prt pht],
        "direction" => "ltr",
        "epubmaker" => {
          "flattoc" => nil,
          "flattocindent" => true,
          "ncx_indent" => [],
          "zip_stage1" => "zip -0Xq",
          "zip_stage2" => "zip -Xr9Dq",
          "zip_addpath" => nil,
          "hook_beforeprocess" => nil,
          "hook_afterfrontmatter" => nil,
          "hook_afterbody" => nil,
          "hook_afterbackmatter" => nil,
          "hook_aftercopyimage" => nil,
          "hook_prepack" => nil,
          "rename_for_legacy" => nil,
          "verify_target_images" => nil,
          "force_include_images" => [],
          "cover_linear" => nil,
        },
        "imagedir" => "images",
        "fontdir" => "fonts",
        "image_ext" => %w(png gif jpg jpeg svg ttf woff otf),
        "font_ext" => %w(ttf woff otf),
      })

      @params = defaults.deep_merge(@params)
      @params["title"] = @params["booktitle"] unless @params["title"]

      deprecated_parameters = {
        "ncxindent" => "epubmaker:ncxindent",
        "flattoc" => "epubmaker:flattoc",
        "flattocindent" => "epubmaker:flattocindent",
        "hook_beforeprocess" => "epubmaker:hook_beforeprocess",
        "hook_afterfrontmatter" => "epubmaker:hook_afterfrontmatter",
        "hook_afterbody" => "epubmaker:hook_afterbody",
        "hook_afterbackmatter" => "epubmaker:hook_afterbackmatter",
        "hook_aftercopyimage" => "epubmaker:hook_aftercopyimage",
        "hook_prepack" => "epubmaker:hook_prepack",
        "rename_for_legacy" => "epubmaker:rename_for_legacy",
        "zip_stage1" => "epubmaker:zip_stage1",
        "zip_stage2" => "epubmaker:zip_stage2",
        "zip_addpath" => "epubmaker:zip_addpath",
        "verify_target_images" => "epubmaker:verify_target_images",
        "force_include_images" => "epubmaker:force_include_images",
        "cover_linear" => "epubmaker:cover_linear",
      }

      deprecated_parameters.each_pair do |k, v|
        unless @params[k].nil?
          sa = v.split(":", 2)
          warn "Parameter #{k} is deprecated. Use:\n#{sa[0]}:\n  #{sa[1]}: ...\n\n"
          @params[sa[0]][sa[1]] = @params[k]
          @params.delete(k)
        end
      end

      @params["htmlversion"] = 5 if @params["epubversion"] >= 3

      %w[bookname title].each do |k|
        raise "Key #{k} must have a value. Abort." unless @params[k]
      end
      # array
      %w[subject aut a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-dsr a-edt a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl adp ann arr art asn aut aqt aft aui ant bkp clb cmm dsr edt ill lyr mdc mus nrt oth pht pbl prt red rev spn ths trc trl stylesheet rights].each do |item|
        next unless @params[item]
        @params[item] = [@params[item]] if @params[item].kind_of?(String)
      end
      # optional
      # type, format, identifier, source, relation, coverpage, aut
    end

    def support_legacy_maker
      # legacy review-epubmaker support
      if @params["flag_legacy_coverfile"].nil? && !@params["coverfile"].nil? && File.exist?(@params["coverfile"])
        @params["cover"] = "#{@params["bookname"]}-cover.#{@params["htmlext"]}"
        @epub.legacy_cover_and_title_file(@params["coverfile"], @params["cover"])
        @params["flag_legacy_coverfile"] = true
        warn "Parameter 'coverfile' is obsolete. Please use 'cover' and make complete html file with header and footer."
      end

      if @params["flag_legacy_titlepagefile"].nil? && !@params["titlepagefile"].nil? && File.exist?(@params["titlepagefile"])
        @params["titlefile"] = "#{@params["bookname"]}-title.#{@params["htmlext"]}"
        @params["titlepage"] = true
        @epub.legacy_cover_and_title_file(@params["titlepagefile"], @params["titlefile"])
        @params["flag_legacy_titlepagefile"] = true
        warn "Parameter 'titlepagefile' is obsolete. Please use 'titlefile' and make complete html file with header and footer."
      end

      if @params["flag_legacy_backcoverfile"].nil? && !@params["backcoverfile"].nil? && File.exist?(@params["backcoverfile"])
        @params["backcover"] = "#{@params["bookname"]}-backcover.#{@params["htmlext"]}"
        @epub.legacy_cover_and_title_file(@params["backcoverfile"], @params["backcover"])
        @params["flag_legacy_backcoverfile"] = true
        warn "Parameter 'backcoverfile' is obsolete. Please use 'backcover' and make complete html file with header and footer."
      end

      if @params["flag_legacy_pubhistory"].nil? && !@params["pubhistory"].nil?
        @params["history"] = [[]]
        @params["pubhistory"].split("\n").each do |date|
          @params["history"][0].push(date.sub(/(\d+)年(\d+)月(\d+)日/, '\1-\2-\3'))
        end
        @params["flag_legacy_pubhistory"] = true
        warn "Parameter 'pubhistory' is obsolete. Please use 'history' array."
      end
    end
  end
end
