# -*- coding: utf-8 -*-
require 'yaml'

module ReVIEW
  class I18n
    ALPHA_U = %w[0 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z]
    ALPHA_L = %w[0 a b c d e f g h i j k l m n o p q r s t u v w x y z]
    ROMAN_U = %w[0 I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII XVIII XIX XX XXI XXII XXIII XXIV XXV XXVI XXVII]
    ROMAN_L = %w[0 i ii iii iv v vi vii viii ix x xi xii xiii xiv xv xvi xvii xviii xix xx xxi xxii xxiii xxiv xxv xxvi xxvii]

    def self.setup(locale="ja", ymlfile = "locale.yml")
      @i18n = ReVIEW::I18n.new(locale)

      lfile = nil
      if ymlfile
        lfile = File.expand_path(ymlfile, Dir.pwd)

        # backward compatibility
        if !File.exist?(lfile) && (ymlfile == "locale.yml")
          lfile = File.expand_path("locale.yaml", Dir.pwd)
        end
      end

      if lfile && File.file?(lfile)
        @i18n.update_localefile(lfile)
      end
    end

    def self.i18n(*args)
      raise NotImplementedError, "I18n.i18n is obsoleted. Please use I18n.setup(locale, [ymlfile])"
    end

    def self.t(str, args = nil)
      @i18n.t(str, args)
    end

    def self.locale=(locale)
      if @i18n
        @i18n.locale = locale
      else
        I18n.setup(locale)
      end
    end

    class << self
      alias_method :v, :t ## for EPUBMaker backward compatibility
    end

    def self.update(user_i18n, locale = nil)
      @i18n.update(user_i18n, locale)
    end

    def self.get(word, locale = nil)
      @i18n.get(word, locale)
    end

    attr_accessor :locale

    def initialize(locale = nil)
      @locale = locale
      load_default
    end

    def load_default
      load_file(File.expand_path("i18n.yml", File.dirname(__FILE__)))
    end

    def load_file(path)
      @store = YAML.load_file(path)
    end

    def update_localefile(path)
      user_i18n = YAML.load_file(path)
      locale = user_i18n["locale"]
      if locale
        user_i18n.delete("locale")
        if @store[locale]
          @store[locale].merge!(user_i18n)
        else
          @store[locale] = user_i18n
        end
      else
        user_i18n.each do |key, values|
          raise KeyError, "Invalid locale file: #{path}" unless values.kind_of? Hash
          @store[key].merge!(values)
        end
      end
    end

    def update(user_i18n, locale = nil)
      locale ||= @locale
      if @store[locale]
        @store[locale].merge!(user_i18n)
      else
        @store[locale] = user_i18n
      end
    end

    def get(word, locale = nil)
      locale ||= @locale
      @store[locale][word]
    end

    def t(str, args = nil)
      args = [args] unless args.is_a? Array

      frmt = @store[@locale][str]
      frmt.gsub!('%%', '##')
      percents = frmt.scan(/%\w\w?/)
      percents.each_with_index do |i, idx|
        case i
        when "%pA"
          frmt.sub!(i, ALPHA_U[args[idx]])
          args.delete idx
        when "%pa"
          frmt.sub!(i, ALPHA_L[args[idx]])
          args.delete idx
        when "%pR"
          frmt.sub!(i, ROMAN_U[args[idx]])
          args.delete idx
        when "%pr"
          frmt.sub!(i, ROMAN_L[args[idx]])
          args.delete idx
        end
      end
      frmt.gsub!('##', '%%')
      frmt % args
    rescue
      str
    end
  end
end
