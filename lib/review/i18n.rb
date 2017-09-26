require 'yaml'

module ReVIEW
  class I18n
    ALPHA_U = %w[0 A B C D E F G H I J K L M N O P Q R S T U V W X Y Z].freeze
    ALPHA_L = %w[0 a b c d e f g h i j k l m n o p q r s t u v w x y z].freeze
    ROMAN_U = %w[0 I II III IV V VI VII VIII IX X XI XII XIII XIV XV XVI XVII XVIII XIX XX XXI XXII XXIII XXIV XXV XXVI XXVII].freeze
    ROMAN_L = %w[0 i ii iii iv v vi vii viii ix x xi xii xiii xiv xv xvi xvii xviii xix xx xxi xxii xxiii xxiv xxv xxvi xxvii].freeze
    ALPHA_UW = %w[０ Ａ Ｂ Ｃ Ｄ Ｅ Ｆ Ｇ Ｈ Ｉ Ｊ Ｋ Ｌ Ｍ Ｎ Ｏ Ｐ Ｑ Ｒ Ｓ Ｔ Ｕ Ｖ Ｗ Ｘ Ｙ Ｚ].freeze
    ALPHA_LW = %w[０ ａ ｂ ｃ ｄ ｅ ｆ ｇ ｈ ｉ ｊ ｋ ｌ ｍ ｎ ｏ ｐ ｑ ｒ ｓ ｔ ｕ ｖ ｗ ｘ ｙ ｚ].freeze
    ROMAN_UW = %w[０ Ⅰ Ⅱ Ⅲ Ⅳ Ｖ Ⅵ Ⅶ Ⅷ Ⅸ Ｘ Ⅺ Ⅻ].freeze
    ARABIC_UW = %w[〇 １ ２ ３ ４ ５ ６ ７ ８ ９ １０ １１ １２ １３ １４ １５ １６ １７ １８ １９ ２０ ２１ ２２ ２３ ２４ ２５ ２６ ２７].freeze
    ARABIC_LW = %w[〇 １ ２ ３ ４ ５ ６ ７ ８ ９ 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27].freeze
    JAPAN = %w[〇 一 二 三 四 五 六 七 八 九 十 十一 十二 十三 十四 十五 十六 十七 十八 十九 二十 二十一 二十二 二十三 二十四 二十五 二十六 二十七].freeze

    def self.setup(locale = 'ja', ymlfile = 'locale.yml')
      @i18n = ReVIEW::I18n.new(locale)

      lfile = nil
      if ymlfile
        lfile = File.expand_path(ymlfile, Dir.pwd)

        # backward compatibility
        raise ReVIEW::ConfigError, 'locale.yaml is obsoleted. Please use locale.yml.' if !File.exist?(lfile) && (ymlfile == 'locale.yml') && File.exist?(File.expand_path('locale.yaml', Dir.pwd))
      end

      @i18n.update_localefile(lfile) if lfile && File.file?(lfile)
    end

    def self.i18n(*_args)
      raise NotImplementedError, 'I18n.i18n is obsoleted. Please use I18n.setup(locale, [ymlfile])'
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
      load_file(File.expand_path('i18n.yml', File.dirname(__FILE__)))
    end

    def load_file(path)
      @store = YAML.load_file(path)
    end

    def update_localefile(path)
      user_i18n = YAML.load_file(path)
      locale = user_i18n['locale']
      if locale
        user_i18n.delete('locale')
        if @store[locale]
          @store[locale].merge!(user_i18n)
        else
          @store[locale] = user_i18n
        end
      else
        user_i18n.each do |key, values|
          raise KeyError, "Invalid locale file: #{path}" unless values.is_a? Hash
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
      frmt = @store[@locale][str].dup
      frmt.gsub!('%%', '##')

      unless args.is_a?(Array)
        args = args.nil? && frmt !~ /\%/ ? [] : [args]
      end

      percents = frmt.scan(/%[A-Za-z]{1,3}/)
      remove_args = []
      percents.each_with_index do |i, idx|
        case i
        when '%pA'
          frmt.sub!(i, ALPHA_U[args[idx]])
          remove_args << idx
        when '%pa'
          frmt.sub!(i, ALPHA_L[args[idx]])
          remove_args << idx
        when '%pAW'
          frmt.sub!(i, ALPHA_UW[args[idx]])
          remove_args << idx
        when '%paW'
          frmt.sub!(i, ALPHA_LW[args[idx]])
          remove_args << idx
        when '%pR'
          frmt.sub!(i, ROMAN_U[args[idx]])
          remove_args << idx
        when '%pr'
          frmt.sub!(i, ROMAN_L[args[idx]])
          remove_args << idx
        when '%pRW'
          frmt.sub!(i, ROMAN_UW[args[idx]])
          remove_args << idx
        when '%pJ'
          frmt.sub!(i, JAPAN[args[idx]])
          remove_args << idx
        when '%pdW'
          frmt.sub!(i, ARABIC_LW[args[idx]])
          remove_args << idx
        when '%pDW'
          frmt.sub!(i, ARABIC_UW[args[idx]])
          remove_args << idx
        end
      end
      remove_args.reverse_each do |idx|
        args.delete_at idx
      end
      args_matched = (frmt.count('%') <= args.size)
      frmt.gsub!('##', '%%')
      args_matched ? (frmt % args) : frmt
    rescue
      str
    end
  end
end
