# encoding: utf-8
# = producer.rb -- EPUB producer.
#
# Copyright (c) 2010-2014 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".

require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'uuid'
require 'epubmaker/resource'
require 'epubmaker/content'
require 'epubmaker/epubv2'
require 'epubmaker/epubv3'

module EPUBMaker
  # EPUBMaker produces EPUB file.
  class Producer
    # Array of content objects.
    attr_accessor :contents
    # Parameter hash.
    attr_accessor :params
    # Message resource object.
    attr_accessor :res
    
    # Take YAML +file+ and return parameter hash.
    def Producer.load(file)
      raise "Can't open #{yamlfile}." if file.nil? || !File.exist?(file)
      return YAML.load_file(file)
    end
    
    # Take YAML +file+ and update parameter hash.
    def load(file)
      raise "Can't open #{yamlfile}." if file.nil? || !File.exist?(file)
      merge_params(@params.merge(YAML.load_file(file)))
    end
    
    # Construct producer object.
    # +params+ takes initial parameter hash. This parameters can be overriden by EPUBMaker#load or EPUBMaker#merge_params.
    # +version+ takes EPUB version (default is 2).
    def initialize(params=nil, version=nil)
      @contents = []
      @params = {}
      @epub = nil
      @params["epubversion"] = version unless version.nil?
      
      unless params.nil?
        merge_params(params)
      end
    end
    
    # Update parameters by merging from new parameter hash +params+.
    def merge_params(params)
      @params = @params.merge(params)
      complement
      @res = EPUBMaker::Resource.new(@params)
      
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
      s = @epub.cover
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
        next if f =~ /\A\./
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

    alias importImageInfo import_imageinfo
    
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
        system(filename, *params)
      end
    end
    
    private

    # Complement parameters.
    def complement
      @params["htmlext"] = "html" if @params["htmlext"].nil?
      defaults = {
        "cover" => "#{@params["bookname"]}.#{@params["htmlext"]}",
        "title" => @params["booktitle"],
        "language" => "ja",
        "date" => Time.now.strftime("%Y-%m-%d"),
        "modified" => Time.now.strftime("%Y-%02m-%02dT%02H:%02M:%02SZ"),
        "urnid" => "urn:uid:#{UUID.create}",
        "isbn" => nil,
        "tocfile" => "toc.#{@params["htmlext"]}",
        "toclevel" => 2,
        "stylesheet" => [],
        "epubversion" => 2,
        "htmlversion" => 4,
        "secnolevel" => 2,
        "pre_secnolevel" => 0,
        "post_secnolevel" => 0,
        "part_secnolevel" => 1,
        "titlepage" => nil,
        "titlepagefile" => nil,
        "originaltitlefile" => nil,
        "profile" => nil,
        "colophon" => nil,
        "zip_stage1" => "zip -0Xq",
        "zip_stage2" => "zip -Xr9Dq",
        "hook_beforeprocess" => nil,
        "hook_afterfrontmatter" => nil,
        "hook_afterbody" => nil,
        "hook_afterbackmatter" => nil,
        "hook_aftercopyimage" => nil,
        "hook_prepack" => nil,
        "rename_for_legacy" => nil,
        "imagedir" => "images",
        "fontdir" => "fonts",
        "image_ext" => %w(png gif jpg jpeg svg ttf woff otf),
        "font_ext" => %w(ttf woff otf),
      }

      defaults.each_pair do |k, v|
        @params[k] = v if @params[k].nil?
      end

      @params["htmlversion"] == 5 if @params["epubversion"] >= 3
      
      %w[bookname title].each do |k|
        raise "Key #{k} must have a value. Abort." if @params[k].nil?
      end
      # array
      %w[subject aut a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-dsr a-edt a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl adp ann arr art asn aut aqt aft aui ant bkp clb cmm dsr edt ill lyr mdc mus nrt oth pht prt red rev spn ths trc trl stylesheet].each do |item|
        @params[item] = [@params[item]] if !@params[item].nil? && @params[item].instance_of?(String)
      end
      # optional
      # type, format, identifier, source, relation, coverpage, rights, aut
    end
  end
end
