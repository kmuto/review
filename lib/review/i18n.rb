require 'yaml'

module ReVIEW
  class I18n
    def self.i18n=(locale)
      locale ||= "ja"
      i18n_yaml_path = File.expand_path "i18n.yaml", File.dirname(__FILE__)
      @i18n = YAML.load_file(i18n_yaml_path)[locale]
    end

    def self.t(str, args = nil)
      @i18n[str] % args
    rescue
      str
    end
  end

  I18n.i18n = begin
    YAML.load_file(File.expand_path "config.yaml", ENV["PWD"])["locale"]
  rescue
    "ja"
  end
end
