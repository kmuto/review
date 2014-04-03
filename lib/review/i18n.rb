# -*- coding: utf-8 -*-
require 'yaml'

module ReVIEW
  class I18n
    def self.setup
      user_i18n = YAML.load_file(File.expand_path "locale.yml", ENV["PWD"])
      I18n.i18n user_i18n["locale"], user_i18n
    rescue
      I18n.i18n "ja"
    end

    def self.i18n(locale, user_i18n = {})
      locale ||= "ja"
      i18n_yaml_path = File.expand_path "i18n.yml", File.dirname(__FILE__)
      @i18n = YAML.load_file(i18n_yaml_path)[locale]
      if @i18n
        @i18n.merge!(user_i18n)
      end
    end

    def self.t(str, args = nil)
      @i18n[str] % args
    rescue
      str
    end
  end

  I18n.setup
end
