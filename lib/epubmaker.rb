# = epubmaker.rb -- EPUB production set.
#
# Copyright (c) 2010-2017 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
# == Quick usage
#  require 'epubmaker'
#  producer = EPUBMaker::Producer.new
#  config = producer.load("config.yml")
#  producer.contents.push(EPUBMaker::Content.new({"file" => "ch01.xhtml"}))
#  producer.contents.push(EPUBMaker::Content.new({"file" => "ch02.xhtml"}))
#   ...
#  producer.import_imageinfo("images")
#  producer.produce

require 'epubmaker/producer'
require 'epubmaker/content'
require 'epubmaker/epubv2'
require 'epubmaker/epubv3'
