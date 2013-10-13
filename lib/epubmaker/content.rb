# encoding: utf-8
# = content.rb -- Content object for EPUBMaker.
#
# Copyright (c) 2010-2013 Kenshi Muto
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

    # :call-seq:
    #    initialize(file, id, media, title, level, notoc)
    #    initialize(hash)
    # Construct Content object by passing a sequence of parameters or hash.
    # Keys of +hash+ relate with each parameters.
    # +file+ (or +hash+["file"]) is required. Others are optional.
    def initialize(fileorhash, id=nil, media=nil, title=nil, level=nil, notoc=nil)
      if fileorhash.instance_of?(Hash)
        @id = fileorhash["id"]
        @file = fileorhash["file"]
        @media = fileorhash["media"]
        @title = fileorhash["title"]
        @level = fileorhash["level"]
        @notoc = fileorhash["notoc"]
      else
        @file = fileorhash
        @id = id
        @media = media
        @title = title
        @level = level
        @notoc = notoc
      end
      complement
    end

    def ==(obj)
      if self.class != obj.class
        return false
      end
      [self.id, self.file, self.media, self.title, self.level, self.notoc] ==
        [obj.id, obj.file, obj.media, obj.title, obj.level, obj.notoc]
    end

    private

    # Complement other parameters by using file parameter.
    def complement
      @id = @file.gsub(/[\\\/\. ]/, '-') if @id.nil?
      @id = "rv-#{@id}" if @id =~ /\A[^a-z]/i
      @media = @file.sub(/.+\./, '').downcase if !@file.nil? && @media.nil?

      @media = "application/xhtml+xml" if @media == "xhtml" || @media == "xml" || @media == "html"
      @media = "text/css" if @media == "css"
      @media = "image/jpeg" if @media == "jpg" || @media == "jpeg" || @media == "image/jpg"
      @media = "image/png" if @media == "png"
      @media = "image/gif" if @media == "gif"
      @media = "image/svg" if @media == "svg"
      @media = "image/svg+xml" if @media == "svg" || @media == "image/svg"

      if @id.nil? || @file.nil? || @media.nil?
        raise "Type error: #{id}, #{file}, #{media}, #{title}, #{notoc}"
      end
    end
  end
end
