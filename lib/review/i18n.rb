# -*- coding: utf-8 -*-
require 'yaml'

module ReVIEW
  class I18n
    def self.setup(ymlfile = "locale.yml")
      lfile = nil
      if ymlfile
        lfile = File.expand_path(ymlfile, Dir.pwd)

        # backward compatibility
        if !File.exist?(lfile) && (ymlfile == "locale.yml")
          lfile = File.expand_path("locale.yaml", Dir.pwd)
        end
      end

      I18n.i18n "ja"
      if lfile && File.file?(lfile)
        @i18n.update_localefile(lfile)
      end
    rescue
      I18n.i18n "ja"
    end

    def self.i18n(locale, user_i18n = {})
      locale ||= "ja"
      @i18n = ReVIEW::I18n.new(locale)
      unless user_i18n.empty?
        @i18n.update(user_i18n)
      end
    end

    def self.t(str, args = nil)
      @i18n.t(str, args)
    end


    attr_accessor :locale

    def initialize(locale = nil)
      @locale = locale
      load_default
    end

    def load_default
      load_file(File.expand_path "i18n.yml", File.dirname(__FILE__))
    end

    def load_file(path)
      @store = YAML.load_file(path)
    end

    def update_localefile(path)
      user_i18n = YAML.load_file(path)
      locale = user_i18n["locale"]
      user_i18n.delete("locale")
      @store[locale].merge!(user_i18n)
    end

    def update(user_i18n, locale = nil)
      locale ||= @locale
      if @store[locale]
        @store[locale].merge!(user_i18n)
      end
    end

    def t(str, args = nil)
      @store[@locale][str] % args
    rescue
      str
    end
  end

  I18n.setup
end
