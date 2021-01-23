require 'test_helper'
require 'review/template'

class TemplateTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @name = nil
  end

  def test_load
    tmplfile = File.expand_path('./assets/test.xml.erb', __dir__)
    tmpl = ReVIEW::Template.load(tmplfile)
    assert_equal("<test>\n<name></name>\n</test>\n", tmpl.result(binding))
  end

  def test_open_with_value
    tmplfile = File.expand_path('./assets/test.xml.erb', __dir__)
    tmpl = ReVIEW::Template.load(tmplfile)
    @name = 'test'
    assert_equal("<test>\n<name>test</name>\n</test>\n", tmpl.result(binding))
  end

  def test_generate
    result = ReVIEW::Template.generate(path: './assets/test.xml.erb', binding: binding, template_dir: __dir__)
    assert_equal("<test>\n<name></name>\n</test>\n", result)
  end

  def test_generate_without_template_dir
    result = ReVIEW::Template.generate(path: '../test/assets/test.xml.erb', binding: binding)
    assert_equal("<test>\n<name></name>\n</test>\n", result)
  end
end
