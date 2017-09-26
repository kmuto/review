require 'erb'
require 'review/extentions'
module ReVIEW
  class Template
    include ERB::Util

    TEMPLATE_DIR = File.join(File.dirname(__FILE__), '../../templates')

    def self.load(filename, mode = 1)
      self.new(filename, mode)
    end

    def initialize(filename = nil, mode = nil)
      return unless filename
      content = File.read(filename)
      @erb = ERB.new(content, nil, mode)
    end

    def result(bind_data = nil)
      @erb.result(bind_data)
    end
  end
end
