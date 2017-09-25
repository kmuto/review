require 'test_helper'
require 'review/template'

class TemplateTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @name = nil
  end

  def test_load
    tmplfile = File.expand_path('./assets/test.xml.erb', File.dirname(__FILE__))
    tmpl = ReVIEW::Template.load(tmplfile)
    assert_equal("<test>\n<name></name>\n</test>\n", tmpl.result(binding))
  end

  def test_open_with_value
    tmplfile = File.expand_path('./assets/test.xml.erb', File.dirname(__FILE__))
    tmpl = ReVIEW::Template.load(tmplfile)
    @name = 'test'
    assert_equal("<test>\n<name>test</name>\n</test>\n", tmpl.result(binding))
  end
end
