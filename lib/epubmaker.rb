# encoding: utf-8
# = epubmaker.rb -- EPUB production set.
#
# Copyright (c) 2010-2013 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
# == Quick usage
#  require 'epubmaker'
#  epub = EPUBMaker::Producer.new
#  params = epub.load("config.yaml")
#  epub.contents.push(EPUBMaker::Content.new({"file" => "ch01.xhtml"}))
#  epub.contents.push(EPUBMaker::Content.new({"file" => "ch02.xhtml"}))
#   ...
#  epub.importImageInfo("images")
#  epub.produce

require 'epubmaker/producer'
require 'epubmaker/resource'
require 'epubmaker/content'
require 'epubmaker/epubv2'
require 'epubmaker/epubv3'
