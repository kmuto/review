# = content.rb -- Content object for EPUBMaker.
#
# Copyright (c) 2010-2017 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

module EPUBMaker
  # EPUBMaker::Content represents a content data for EPUBMaker.
  # EPUBMaker#contents takes an array of Content.
  class Content
    # ID
    attr_accessor :id
    # File path (will accept #<anchor> suffix also)
    attr_accessor :file
    # MIME type
    attr_accessor :media
    # Title
    attr_accessor :title
    # Header level (from 1)
    attr_accessor :level
    # Show in TOC? nil:No.
    attr_accessor :notoc
    # Properties (EPUB3)
    attr_accessor :properties
    # Chapter type (pre/post/part/nil(body))
    attr_accessor :chaptype

    def inspect
      "<Content id=#{@id}, file=#{@file}, media=#{@media}, title=#{@title}, level=#{@level}, notoc=#{@notoc}, properties=#{@properties}, chaptype=#{@chaptype}>"
    end

    # :call-seq:
    #    initialize(file, id, media, title, level, notoc)
    #    initialize(hash)
    # Construct Content object by passing a sequence of parameters or hash.
    # Keys of +hash+ relate with each parameters.
    # +file+ (or +hash+["file"]) is required. Others are optional.
    def initialize(fileorhash, id = nil, media = nil, title = nil, level = nil, notoc = nil, properties = nil, chaptype = nil)
      if fileorhash.instance_of?(Hash)
        @id = fileorhash['id']
        @file = fileorhash['file']
        @media = fileorhash['media']
        @title = fileorhash['title']
        @level = fileorhash['level']
        @notoc = fileorhash['notoc']
        @properties = fileorhash['properties'] || []
        @chaptype = fileorhash['chaptype']
      else
        @file = fileorhash
        @id = id
        @media = media
        @title = title
        @level = level
        @notoc = notoc
        @properties = properties || []
        @chaptype = chaptype
      end
      complement
    end

    def ==(other)
      return false unless self.class == other.class
      [self.id, self.file, self.media, self.title, self.level, self.notoc, self.chaptype, self.properties] ==
        [other.id, other.file, other.media, other.title, other.level, other.notoc, other.chaptype, other.properties]
    end

    private

    # Complement other parameters by using file parameter.
    def complement
      if @id.nil?
        @id = @file.gsub(%r{[\\/\. ]}, '-')
      end
      if @id =~ /\A[^a-z]/i
        @id = "rv-#{@id}"
      end

      if !@file.nil? && @media.nil?
        @media = @file.sub(/.+\./, '').downcase
      end

      case @media
      when 'xhtml', 'xml', 'html'
        @media = 'application/xhtml+xml'
      when 'css'
        @media = 'text/css'
      when 'jpg', 'jpeg', 'image/jpg'
        @media = 'image/jpeg'
      when 'png'
        @media = 'image/png'
      when 'gif'
        @media = 'image/gif'
      when 'svg', 'image/svg'
        @media = 'image/svg+xml'
      when 'ttf', 'otf'
        @media = 'application/vnd.ms-opentype'
      when 'woff'
        @media = 'application/font-woff'
      end

      if @id.nil? || @file.nil? || @media.nil?
        raise "Type error: #{id}, #{file}, #{media}, #{title}, #{notoc}"
      end
    end
  end
end
