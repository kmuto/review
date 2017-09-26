require 'test_helper'
require 'review/htmltoc'

class HTMLTocTest < Test::Unit::TestCase
  include ReVIEW

  def setup
  end

  def teardown
  end

  def test_tocfilename
    toc = HTMLToc.new('/var/tmp')
    assert_equal '/var/tmp/toc-html.txt', toc.tocfilename
  end

  def test_encode_args
    toc = HTMLToc.new('/var/tmp')
    assert_equal 'chaptype=pre', toc.encode_args(chaptype: 'pre')
    assert_equal 'force_include=true,chaptype=body,properties=foo', toc.encode_args({ force_include: true, chaptype: 'body', 'properties' => 'foo' })
  end

  def test_decode_args
    toc = HTMLToc.new('/var/tmp')
    assert_equal({ chaptype: 'pre' }, toc.decode_args('chaptype=pre'))
    assert_equal({ force_include: 'true', chaptype: 'body', properties: 'foo' }, toc.decode_args('force_include=true,chaptype=body,properties=foo'))
  end
end
