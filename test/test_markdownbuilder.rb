require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/markdownbuilder'
require 'review/i18n'

class MARKDOWNBuilderTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = MARKDOWNBuilder.new
    @config = ReVIEW::Configure.values
    @book = Book::Base.new('.')
    @book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def test_quote
    actual = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS

> foobar
> 
> buz

EOS
    assert_equal expected, actual
  end

  def test_memo
    actual = compile_block("//memo[this is @<b>{test}<&>_]{\ntest1\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS
<div class="memo">
<p class="caption">this is **test**<&>_</p>
test1
test*2*
</div>
EOS
    assert_equal expected, actual
  end

  def test_noindent
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    expected = <<-EOS
<p class="noindent">foobar</p>

foo2bar2

EOS
    assert_equal expected, actual
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
    expected = <<-EOS
```shell-session
lineA
lineB
```
EOS
    assert_equal expected, actual
  end

  def test_dlist
    actual = compile_block(": foo\n  foo.\n  bar.\n")
    expected = <<-EOS
<dl>
<dt>foo</dt>
<dd>foo.bar.</dd>
</dl>
EOS
    assert_equal expected, actual
  end

  def test_dlist_with_bracket
    actual = compile_block(": foo[bar]\n    foo.\n    bar.\n")
    expected = <<-EOS
<dl>
<dt>foo[bar]</dt>
<dd>foo.bar.</dd>
</dl>
EOS
    assert_equal expected, actual
  end

  def test_dlist_with_comment
    source = ": title\n  body\n\#@ comment\n\#@ comment\n: title2\n  body2\n"
    actual = compile_block(source)
    expected = <<-EOS
<dl>
<dt>title</dt>
<dd>body</dd>
<dt>title2</dt>
<dd>body2</dd>
</dl>
EOS
    assert_equal expected, actual
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
    expected = <<-EOS
|testA|testB|
|:--|:--|
|contentA|contentB|

EOS
    assert_equal expected, actual

    actual = compile_block("//table[foo][FOO]{\ntestA\ttestB\n------------\ncontentA\tcontentB\n//}\n")
    expected = <<-EOS
表1.1: FOO

|testA|testB|
|:--|:--|
|contentA|contentB|

EOS
    assert_equal expected, actual
  end

  def test_ruby
    actual = compile_block('@<ruby>{謳,うた}い文句')
    assert_equal "<ruby>謳<rp>（</rp><rt>うた</rt><rp>）</rp></ruby>い文句\n\n", actual
  end
end
