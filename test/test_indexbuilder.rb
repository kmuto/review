require 'test_helper'
require 'review/builder'

require 'review/book'

class MockCompiler
  def text(s)
    [:text, s]
  end
end

class IndexBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @b = IndexBuilder.new
    chap = ReVIEW::Book::Chapter.new(nil, nil, '-', nil)
    @b.bind(MockCompiler.new, chap, nil)
  end

  def test_initialize
    assert IndexBuilder.new
  end

  def test_check_id
    io = StringIO.new
    @b.instance_eval { @logger = ReVIEW::Logger.new(io) }
    @b.check_id('ABC')
    assert_match('', io.string)

    %w(# % \\ { } [ ] ~ / $ ' " | * ? & < > `).each do |c|
      io = StringIO.new
      @b.instance_eval { @logger = ReVIEW::Logger.new(io) }
      @b.check_id("id#{c}")
      assert_match(/deprecated ID: `#{Regexp.escape(c)}` in `id#{Regexp.escape(c)}`/, io.string)
    end
    io = StringIO.new
    @b.instance_eval { @logger = ReVIEW::Logger.new(io) }
    @b.check_id('A B C#')
    assert_match(/deprecated ID: ` ` in `A B C#`/, io.string)

    io = StringIO.new
    @b.instance_eval { @logger = ReVIEW::Logger.new(io) }
    @b.check_id("A\tB")
    assert_match(/deprecated ID: `\t` in `A\tB`/, io.string)

    io = StringIO.new
    @b.instance_eval { @logger = ReVIEW::Logger.new(io) }
    @b.check_id('.ABC')
    assert_match(/deprecated ID: `.ABC` begins from `.`/, io.string)
  end
end
