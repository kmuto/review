# encoding: utf-8
# = resource.rb -- Message resources for EPUBMaker.
#
# Copyright (c) 2010-2013 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

module EPUBMaker

# EPUBMaker::Resource contains message translation resources for EPUBMaker.
  class Resource
    # Construct message resource object with using +params+["language"] value.
    def initialize(params)
      @hash = nil
      begin
        @hash = __send__ params["language"]
      rescue
        @hash = __send__ :en
      end

      @hash.each_pair do |k, v|
        @hash[k] = params[k] unless params[k].nil?
      end
    end

    # Return message translation for +key+.
    def v(key)
      return @hash[key]
    end

    private
    # English message catalog
    def en
      {
        "toctitle" => "Table of Contents",
        "covertitle" => "Cover",
        "titlepagetitle" => "Title Page",
        "originaltitle" => "Title Page of Original",
        "credittitle" => "Credit",
        "colophontitle" => "Colophon",
        "profiletitle" => "Profile",
        "advtitle" => "Advertisement",
        "c-aut" => "Author",
        "c-csl" => "Consultant",
        "c-dsr" => "Designer",
        "c-ill" => "Illustrator",
        "c-edt" => "Editor",
        "c-pht" => "Director of Photography",
        "c-trl" => "Translator",
        "c-prt" => "Publisher",
      }
    end

    # Japanese message catalog
    def ja
      {
        "toctitle" => "目次",
        "covertitle" => "表紙",
        "titlepagetitle" => "大扉",
        "originaltitle" => "原書大扉",
        "credittitle" => "クレジット",
        "colophontitle" => "奥付",
        "advtitle" => "広告",
        "profiletitle" => "著者紹介",
        "c-aut" => "著　者",
        "c-csl" => "監　修",
        "c-dsr" => "デザイン",
        "c-ill" => "イラスト",
        "c-edt" => "編　集",
        "c-pht" => "撮　影",
        "c-trl" => "翻　訳",
        "c-prt" => "発行所",
      }
    end
  end
end
