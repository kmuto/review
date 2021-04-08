require 'erb'
require 'review/extentions'
module ReVIEW
  class Template
    include ERB::Util

    TEMPLATE_DIR = File.join(File.dirname(__FILE__), '../../templates')

    def self.load(filename, mode = 1)
      self.new(filename, mode)
    end

    def self.generate(path:, binding:, mode: 1, template_dir: ReVIEW::Template::TEMPLATE_DIR)
      template_file = File.expand_path(path, template_dir)
      self.new(template_file, mode).result(binding)
    end

    def initialize(filename = nil, mode = nil)
      return unless filename

      content = File.read(filename)
      @erb = if Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('2.6')
               ERB.new(content, trim_mode: mode)
             else
               ERB.new(content, nil, mode)
             end
    end

    def result(bind_data = nil)
      @erb.result(bind_data)
    end
  end
end
