require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/markdownbuilder'
require 'review/i18n'

class MARKDOWNBuilderTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = MARKDOWNBuilder.new
    @config = {
      'secnolevel' => 2,
      'stylesheet' => nil
    }
    @book = Book::Base.new('.')
    @book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def test_quote
    actual = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q(\n> foobar\n> \n> buz\n\n), actual
  end

  def test_inline_em
    assert_equal 'test*foo*abc', compile_inline('test@<em>{foo}abc')
  end

  def test_inline_strong
    assert_equal 'test**foo**abc', compile_inline('test@<strong>{foo}abc')
  end

  def test_ul
    src = <<-EOS
  * AAA
  * BBB
EOS
    expected = "\n* AAA\n* BBB\n\n"
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_inline_comment
    actual = compile_inline('test @<comment>{コメント} test2')
    assert_equal 'test  test2', actual
  end

  def test_inline_comment_for_draft
    @config['draft'] = true
    actual = compile_inline('test @<comment>{コメント} test2')
    assert_equal %Q(test <span class="red">コメント</span> test2), actual
  end

  def test_ul_nest1
    src = <<-EOS
  * AAA
  ** AA
  *** A
EOS
    expected = "\n* AAA\n  * AA\n    * A\n\n"
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_cmd
    actual = compile_block("//cmd{\nlineA\nlineB\n//}\n")
    assert_equal "```shell-session\nlineA\nlineB\n```\n", actual
  end

  def test_dlist
    actual = compile_block(": foo\n  foo.\n  bar.\n")
    assert_equal %Q(<dl>\n<dt>foo</dt>\n<dd>foo.bar.</dd>\n</dl>\n), actual
  end

  def test_dlist_with_bracket
    actual = compile_block(": foo[bar]\n    foo.\n    bar.\n")
    assert_equal %Q(<dl>\n<dt>foo[bar]</dt>\n<dd>foo.bar.</dd>\n</dl>\n), actual
  end

  def test_dlist_with_comment
    source = ": title\n  body\n\#@ comment\n\#@ comment\n: title2\n  body2\n"
    actual = compile_block(source)
    assert_equal %Q(<dl>\n<dt>title</dt>\n<dd>body</dd>\n<dt>title2</dt>\n<dd>body2</dd>\n</dl>\n), actual
  end

  def test_comment
    actual = compile_block('//comment[コメント]')
    assert_equal '', actual
  end

  def test_comment_for_draft
    @config['draft'] = true
    actual = compile_block('//comment[コメント]')
    assert_equal %Q(<div class="red">コメント</div>\n), actual
  end

  def test_list
    actual = compile_block(<<-EOS)
//list[name][caption]{
AAA
BBB
//}
    EOS

    assert_equal <<-EOS, actual
リスト1.1 caption

```
AAA
BBB
```
    EOS
  end

  def test_list_lang
    actual = compile_block(<<-EOS)
//list[name][caption][ruby]{
AAA
BBB
//}
    EOS

    assert_equal <<-EOS, actual
リスト1.1 caption

```ruby
AAA
BBB
```
    EOS
  end

  def test_emlist_lang
    actual = compile_block(<<-EOS)
//emlist[caption][ruby]{
AAA
BBB
//}
    EOS

    assert_equal <<-EOS, actual

caption

```ruby
AAA
BBB
```

    EOS
  end

  def test_table
    actual = compile_block("//table{\ntestA\ttestB\n------------\ncontentA\tcontentB\n//}\n")
    assert_equal "|testA|testB|\n|:--|:--|\n|contentA|contentB|\n\n", actual
  end

  def test_ruby
    actual = compile_block('@<ruby>{謳,うた}い文句')
    assert_equal "<ruby><rb>謳</rb><rp>（</rp><rt>うた</rt><rp>）</rp></ruby>い文句\n\n", actual
  end
end
