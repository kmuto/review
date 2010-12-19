# encoding: utf-8
# = producer.rb -- EPUB producer.
#
# Copyright (c) 2010 Kenshi Muto
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
      mergeparams(@params.merge(YAML.load_file(file)))
    end
    
    # Construct producer object.
    # +params+ takes initial parameter hash. This parameters can be overriden by EPUBMaker#load or EPUBMaker#mergeparams.
    # +version+ takes EPUB version (default is 2).
    def initialize(params=nil, version=nil)
      @contents = []
      @params = {}
      @epub = nil
      @params["epubversion"] = version unless version.nil?
      
      unless params.nil?
        mergeparams(params)
      end
    end
    
    # Update parameters by merging from new parameter hash +params+.
    def mergeparams(params)
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
      wobj.puts s if !s.nil? && !wobj.nil?
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
      s = @epub.colophon
      wobj.puts s if !s.nil? && !wobj.nil?
    end
    
    # Add informations of figure files in +path+ to contents array.
    # +base+ defines a string to remove from path name.
    def importImageInfo(path, base=nil)
      Dir.foreach(path) do |f|
        next if f =~ /\A\./
        if f =~ /\.(png|jpg|jpeg|svg|gif)\Z/i  # FIXME:EPUB3 accepts more types...
          path.chop! if path =~ /\/\Z/
          if base.nil?
            @contents.push(EPUBMaker::Content.new({"file" => "#{path}/#{f}"}))
          else
            @contents.push(EPUBMaker::Content.new({"file" => "#{path.sub(base + "/", '')}/#{f}"}))
          end
        end
        if FileTest.directory?("#{path}/#{f}")
          importImageInfo("#{path}/#{f}", base)
        end
      end
    end
    
    # Produce EPUB file +epubfile+.
    # +basedir+ points the directory has contents (default: current directory.)
    # +tmpdir+ defines temporary directory.
    def produce(epubfile, basedir=nil, tmpdir=nil)
      current = Dir.pwd
      basedir = current if basedir.nil?
      # FIXME: produce cover, mytoc, titlepage, colophon?
      
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
    
    private
    
    # Complement parameters.
    def complement
      # FIXME: should separate for EPUB2/3?
      # FIXME: escapeHTML?
      # use default value if not defined
      @params["htmlext"] = "html" if @params["htmlext"].nil?
      defaults = {
        "cover" => "#{@params["bookname"]}.#{@params["htmlext"]}",
        "title" => @params["booktitle"], # backward compatibility
        "language" => "ja",
        "date" => Time.now.strftime("%Y-%m-%d"),
        "urnid" => "urn:uid:#{UUID.create}",
        "tocfile" => "toc.#{@params["htmlext"]}",
        "toclevel" => 2,
        "stylesheet" => [],
        "epubversion" => 2,
      }
      defaults.each_pair do |k, v|
        @params[k] = v if @params[k].nil?
      end
      
      # must be defined
      %w[bookname title].each do |k|
        raise "Key #{k} must have a value. Abort." if @params[k].nil? # FIXME: should not be error?
    end
      # array
      %w[subject aut a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-dsr a-edt a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl adp ann arr art asn aut aqt aft aui ant bkp clb cmm dsr edt ill lyr mdc mus nrt oth pht prt red rev spn ths trc trl stylesheet].each do |item|
        @params[item] = [@params[item]] if !@params[item].nil? && @params[item].instance_of?(String) # FIXME: avoid double insert
    end
      # optional
      # type, format, identifier, source, relation, coverpage, rights, aut
    end
  end
end
