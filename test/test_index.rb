require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/book/index'
require 'review/topbuilder'
require 'review/i18n'

class IndexTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = TOPBuilder.new
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = Book::Base.new
    @book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)

    I18n.setup(@config['language'])
  end

  def test_footnote_index
    compile_block("//footnote[foo][bar]\n")
    fn = @chapter.footnote_index
    items = fn.to_a
    item = items[0]
    assert_equal 'foo', item.id
    assert_equal 'bar', item.content
  end

  def test_footnote_index_with_escape
    compile_block('//footnote[foo][bar[\]buz]' + "\n")
    fn = @chapter.footnote_index
    items = fn.to_a
    item = items[0]
    assert_equal 'foo', item.id
    assert_equal 'bar[]buz', item.content
  end

  def test_footnote_index_with_escape2
    compile_block('//footnote[foo][bar\\a\\$buz]' + "\n")
    fn = @chapter.footnote_index
    items = fn.to_a
    item = items[0]
    assert_equal 'foo', item.id
    assert_equal 'bar\\a\\$buz', item.content
  end

  def test_footnote_index_key?
    compile_block('//footnote[foo][bar]' + "\n")
    fn = @chapter.footnote_index
    assert_equal true, fn.key?('foo')

    ## for compatibility
    # rubocop:disable Style/PreferredHashMethods
    assert_equal true, fn.has_key?('foo')
    # rubocop:enable Style/PreferredHashMethods
  end

  def test_headline_index
    src = <<-EOB
= chap1
== sec1-1
== sec1-2
=== sec1-2-1
===[column] column1
==== inside_column
===[/column]
===[column] column2
=== sec1-2-2
== sec1-3
==== sec1-3-0-1
    EOB
    compile_block(src)
    index = @chapter.headline_index
    assert_equal [2, 2], index['sec1-2|sec1-2-2'].number
    assert_equal '1.2.2', index.number('sec1-2|sec1-2-2')
  end

  def test_headline_index2
    src = <<-EOB
= chap1
== sec1-1
== sec1-2
=== sec1-2-1
===[column] column1
== sec1-3
=== sec1-3-1
    EOB
    compile_block(src)
    index = @chapter.headline_index
    assert_equal [3, 1], index['sec1-3|sec1-3-1'].number
    assert_equal '1.3.1', index.number('sec1-3|sec1-3-1')
  end

  def test_headline_index3
    src = <<-EOB
= chap1
== sec1-1
== sec1-2
=== sec1-2-1
===[column] column1
=== sec1-2-2
== sec1-3
=== sec1-3-1
    EOB
    compile_block(src)
    index = @chapter.headline_index
    assert_equal [2, 2], index['sec1-2|sec1-2-2'].number
    assert_equal '1.2.2', index.number('sec1-2|sec1-2-2')

    assert_equal [3, 1], index['sec1-3|sec1-3-1'].number
    assert_equal '1.3.1', index.number('sec1-3|sec1-3-1')
  end

  def test_headline_index4
    src = <<-EOB
= chap1
====[column] c1
== sec1-1
== sec1-2
=== sec1-2-1
=== sec1-2-2
    EOB
    compile_block(src)
    index = @chapter.headline_index
    assert_equal [2, 2], index['sec1-2|sec1-2-2'].number
    assert_equal '1.2.2', index.number('sec1-2|sec1-2-2')
  end

  def test_headline_index5
    src = <<-EOB
= chap1
====[column] c1
== sec1-1
== sec1-2
=== sec1-2-1
=== sec1-2-2
    EOB
    compile_block(src)
    index = @chapter.headline_index
    assert_equal [2, 2], index['sec1-2-2'].number
    assert_equal '1.2.2', index.number('sec1-2-2')
  end

  def test_headline_index6
    src = <<-EOB
= chap1
== sec1
=== target
== sec2

    EOB
    compile_block(src)
    index = @chapter.headline_index
    assert_equal [1, 1], index['target'].number
    assert_equal '1.1.1', index.number('target')
  end

  def test_headline_index7
    src = <<-EOB
= chap1
== sec1
=== target
       ^-- dummy target

== sec2
=== target
       ^-- real target but it cannot be detected, because there is another one.

    EOB
    compile_block(src)
    index = @chapter.headline_index

    assert_raise ReVIEW::KeyError do
      assert_equal [1, 1], index['target'].number
    end
  end

  def test_headline_index8
    src = <<-EOB
= chap1
== sec1
=== sec1-1
==== sec1-1-1

    EOB
    compile_block(src)
    index = @chapter.headline_index

    assert_equal '1.1.1', index.number('sec1-1')
  end

  def test_headline_index9
    src = <<-EOB
= chap1
== sec1
=== sec1-1
===[column] column1
===[/column]
==== sec1-1-1
=== sec1-2
    EOB
    compile_block(src)
    index = @chapter.headline_index
    assert_equal [1, 1, 1], index['sec1-1-1'].number
  end

  def test_headline_index10
    src = <<-EOB
= chap1
== sec1
=== sec1-1
====[column] column1
==== sec1-1-1
=== sec1-2
    EOB
    compile_block(src)
    index = @chapter.headline_index
    assert_equal [1, 1, 1], index['sec1-1-1'].number
  end

  def test_headline_index11
    src = <<-EOB
= chap1
==[nodisp] sec01
==[notoc] sec02
== sec1
===[nodisp] sec1-0
=== sec1-1
==[nonum] sec03
== sec04
    EOB
    compile_block(src)
    index = @chapter.headline_index
    assert_equal nil, index['sec01'].number
    assert_equal nil, index['sec02'].number
    assert_equal [1], index['sec1'].number
    assert_equal nil, index['sec1-0'].number
    assert_equal [1, 1], index['sec1-1'].number
    assert_equal nil, index['sec03'].number
    assert_equal [2], index['sec04'].number
  end

  def test_headline_index12
    src = <<-EOB
= chap1
== A
=== A2
==[nonum] B
=== B2
    EOB
    compile_block(src)
    index = @chapter.headline_index
    assert_equal [1], index['A'].number
    assert_equal [1, 1], index['A2'].number
    assert_equal nil, index['B'].number
    assert_equal [1, 2], index['B2'].number
  end
end
