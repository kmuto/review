# encoding: utf-8

require 'test_helper'
require 'review/compiler'
require 'review/book'
require 'review/htmlbuilder'
require 'review/i18n'

class HTMLBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = HTMLBuilder.new()
    @config = ReVIEW::Configure.values
    @config.merge!({
      "secnolevel" => 2,    # for IDGXMLBuilder, HTMLBuilder
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "stylesheet" => nil,  # for HTMLBuilder
    })
    ReVIEW.book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(Book::Base.new(nil), 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def test_xmlns_ops_prefix_epub3
    ReVIEW.book.config["epubversion"] = 3
    assert_equal "epub", @builder.xmlns_ops_prefix
  end

  def test_xmlns_ops_prefix_epub2
    assert_equal "ops", @builder.xmlns_ops_prefix
  end

  def test_headline_level1
    result = compile_block("={test} this is test.\n")
    assert_equal %Q|<h1 id="test"><a id="h1"></a>第1章　this is test.</h1>\n|, result
  end

  def test_headline_level1_postdef
    @chapter.instance_eval do
      def on_APPENDIX?
        true
      end
    end
    result = compile_block("={test} this is test.\n")
    assert_equal %Q|<h1 id="test"><a id="h1"></a>付録1　this is test.</h1>\n|, result
  end

  def test_headline_level2_postdef
    @chapter.instance_eval do
      def on_APPENDIX?
        true
      end
    end
    result = compile_block("=={test} this is test.\n")
    assert_equal %Q|\n<h2 id="test"><a id="h1-1"></a>1.1　this is test.</h2>\n|, result
  end

  def test_headline_level1_postdef_roman
    @chapter.book.config["appendix_format"] = "roman"
    @chapter.instance_eval do
      def on_APPENDIX?
        true
      end
    end
    result = compile_block("={test} this is test.\n")
    assert_equal %Q|<h1 id="test"><a id="h1"></a>付録I　this is test.</h1>\n|, result
  end

  def test_headline_level2_postdef_roman
    @chapter.book.config["appendix_format"] = "roman"
    @chapter.instance_eval do
      def on_APPENDIX?
        true
      end
    end
    result = compile_block("=={test} this is test.\n")
    assert_equal %Q|\n<h2 id="test"><a id="h1-1"></a>I.1　this is test.</h2>\n|, result
  end

  def test_headline_level1_postdef_alpha
    @chapter.book.config["appendix_format"] = "alpha"
    @chapter.instance_eval do
      def on_APPENDIX?
        true
      end
    end
    result = compile_block("={test} this is test.\n")
    assert_equal %Q|<h1 id="test"><a id="h1"></a>付録A　this is test.</h1>\n|, result
  end

  def test_headline_level2_postdef_alpha
    @chapter.book.config["appendix_format"] = "alpha"
    @chapter.instance_eval do
      def on_APPENDIX?
        true
      end
    end
    result = compile_block("=={test} this is test.\n")
    assert_equal %Q|\n<h2 id="test"><a id="h1-1"></a>A.1　this is test.</h2>\n|, result
  end

  def test_headline_level1_without_secno
    ReVIEW.book.config["secnolevel"] = 0
    result = compile_block("={test} this is test.\n")
    assert_equal %Q|<h1 id="test"><a id="h1"></a>this is test.</h1>\n|, result
  end

  def test_headline_level1_with_tricky_id
    result = compile_block("={123 あ_;} this is test.\n")
    assert_equal %Q|<h1 id="id_123-_E3_81_82___3B"><a id="h1"></a>第1章　this is test.</h1>\n|, result
  end

  def test_headline_level1_with_inlinetag
    result = compile_block("={test} this @<b>{is} test.<&\">\n")
    assert_equal %Q|<h1 id="test"><a id="h1"></a>第1章　this <b>is</b> test.&lt;&amp;&quot;&gt;</h1>\n|, result
  end

  def test_headline_level2
    result = compile_block("=={test} this is test.\n")
    assert_equal %Q|\n<h2 id="test"><a id="h1-1"></a>1.1　this is test.</h2>\n|, result
  end

  def test_headline_level3
    result = compile_block("==={test} this is test.\n")
    assert_equal %Q|\n<h3 id="test"><a id="h1-0-1"></a>this is test.</h3>\n|, result
  end

  def test_headline_level3_with_secno
    ReVIEW.book.config["secnolevel"] = 3
    result = compile_block("==={test} this is test.\n")
    assert_equal %Q|\n<h3 id="test"><a id="h1-0-1"></a>1.0.1　this is test.</h3>\n|, result
  end

  def test_label
    result = compile_block("//label[label_test]\n")
    assert_equal %Q|<a id="label_test"></a>\n|, result
  end

  def test_label_with_tricky_id
    result = compile_block("//label[123 あ_;]\n")
    assert_equal %Q|<a id="id_123-_E3_81_82___3B"></a>\n|, result
  end

  def test_href
    result = compile_inline("@<href>{http://github.com,GitHub}")
    assert_equal %Q|<a href="http://github.com" class="link">GitHub</a>|, result
  end

  def test_href_without_label
    result = compile_inline("@<href>{http://github.com}")
    assert_equal %Q|<a href="http://github.com" class="link">http://github.com</a>|, result
  end

  def test_inline_href
    result = compile_inline("@<href>{http://github.com,Git\\,Hub}")
    assert_equal %Q|<a href="http://github.com" class="link">Git,Hub</a>|, result
  end

  def test_inline_raw
    result = compile_inline("@<raw>{@<tt>{inline\\}}")
    assert_equal %Q|@<tt>{inline}|, result
  end

  def test_inline_in_table
    result = compile_block("//table{\n@<b>{1}\t@<i>{2}\n------------\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    assert_equal %Q|<div class="table">\n<table>\n<tr><th><b>1</b></th><th><i>2</i></th></tr>\n<tr><td><b>3</b></td><td><i>4</i>&lt;&gt;&amp;</td></tr>\n</table>\n</div>\n|, result
  end

  def test_inline_br
    result = compile_inline("@<br>{}")
    assert_equal %Q|<br />|, result
  end

  def test_inline_i
    result = compile_inline("test @<i>{inline test} test2")
    assert_equal %Q|test <i>inline test</i> test2|, result
  end

  def test_inline_i_and_escape
    result = compile_inline("test @<i>{inline<&;\\ test} test2")
    assert_equal %Q|test <i>inline&lt;&amp;;\\ test</i> test2|, result
  end

  def test_inline_b
    result = compile_inline("test @<b>{inline test} test2")
    assert_equal %Q|test <b>inline test</b> test2|, result
  end

  def test_inline_b_and_escape
    result = compile_inline("test @<b>{inline<&;\\ test} test2")
    assert_equal %Q|test <b>inline&lt;&amp;;\\ test</b> test2|, result
  end

  def test_inline_tt
    result = compile_inline("test @<tt>{inline test} test2")
    assert_equal %Q|test <tt>inline test</tt> test2|, result
  end

  def test_inline_tti
    result = compile_inline("test @<tti>{inline test} test2")
    assert_equal %Q|test <tt><i>inline test</i></tt> test2|, result
  end

  def test_inline_ttb
    result = compile_inline("test @<ttb>{inline test} test2")
    assert_equal %Q|test <tt><b>inline test</b></tt> test2|, result
  end

  def test_inline_hd_chap
    def @chapter.headline_index
      items = [Book::HeadlineIndex::Item.new("chap1|test", [1, 1], "te_st")]
      Book::HeadlineIndex.new(items, self)
    end

    @config["secnolevel"] = 2
    result = compile_inline("test @<hd>{chap1|test} test2")
    assert_equal %Q|test 「te_st」 test2|, result

    @config["secnolevel"] = 3
    result = compile_inline("test @<hd>{chap1|test} test2")
    assert_equal %Q|test 「1.1.1 te_st」 test2|, result
  end

  def test_inline_uchar
    result = compile_inline("test @<uchar>{2460} test2")
    assert_equal %Q|test &#x2460; test2|, result
  end

  def test_inline_ruby
    result = compile_inline("@<ruby>{粗雑,クルード}と思われているなら@<ruby>{繊細,テクニカル}にやり、繊細と思われているなら粗雑にやる。")
    assert_equal "<ruby><rb>粗雑</rb><rp>（</rp><rt>クルード</rt><rp>）</rp></ruby>と思われているなら<ruby><rb>繊細</rb><rp>（</rp><rt>テクニカル</rt><rp>）</rp></ruby>にやり、繊細と思われているなら粗雑にやる。", result
  end

  def test_inline_ruby_comma
    result = compile_inline("@<ruby>{foo\\, bar\\, buz,フー・バー・バズ}")
    assert_equal "<ruby><rb>foo, bar, buz</rb><rp>（</rp><rt>フー・バー・バズ</rt><rp>）</rp></ruby>", result
  end

  def test_inline_ref
    result = compile_inline("@<ref>{外部参照<>&}")
    assert_equal %Q|<a target='外部参照&lt;&gt;&amp;'>「●●　外部参照&lt;&gt;&amp;」</a>|, result
  end

  def test_inline_mathml
    begin
      require 'math_ml'
      require "math_ml/symbol/character_reference"
    rescue LoadError
      return true
    end
    @config["mathml"] = true
    result = compile_inline("@<m>{\\frac{-b \\pm \\sqrt{b^2 - 4ac\\}\\}{2a\\}}")
    @config["mathml"] = nil
    assert_equal "<span class=\"equation\"><math xmlns='http://www.w3.org/1998/Math/MathML' display='inline'><mfrac><mrow><mo stretchy='false'>-</mo><mi>b</mi><mo stretchy='false'>&#xb1;</mo><msqrt><mrow><msup><mi>b</mi><mn>2</mn></msup><mo stretchy='false'>-</mo><mn>4</mn><mi>a</mi><mi>c</mi></mrow></msqrt></mrow><mrow><mn>2</mn><mi>a</mi></mrow></mfrac></math></span>", result
  end

  def test_quote
    result = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|<blockquote><p>foobar</p>\n<p>buz</p></blockquote>\n|, result
  end

  def test_memo
    result = compile_block("//memo[this is @<b>{test}<&>_]{\ntest1\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<div class="memo">\n<p class="caption">this is <b>test</b>&lt;&amp;&gt;_</p>\n<p>test1</p>\n<p>test<i>2</i></p>\n</div>\n|, result
  end

  def test_noindent
    @builder.noindent
    result = compile_block("foo\nbar\n\nfoo2\nbar2\n")
    assert_equal %Q|<p class="noindent">foobar</p>\n<p>foo2bar2</p>\n|, result
  end

  def test_flushright
    result = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|<p class="flushright">foobar</p>\n<p class="flushright">buz</p>\n|, result
  end

  def test_centering
    result = compile_block("//centering{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|<p class="center">foobar</p>\n<p class="center">buz</p>\n|, result
  end

  def test_image
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//image[sampleimg][sample photo]{\n//}\n")
    assert_equal %Q|<div id="sampleimg" class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" />\n<p class="caption">\n図1.1: sample photo\n</p>\n</div>\n|, result
  end

  def test_image_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//image[sampleimg][sample photo][scale=1.2]{\n//}\n")
    assert_equal %Q|<div id="sampleimg" class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" width="120%" />\n<p class="caption">\n図1.1: sample photo\n</p>\n</div>\n|, result
  end

  def test_image_with_metric2
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//image[sampleimg][sample photo][scale=1.2,html::class=sample,latex::ignore=params]{\n//}\n")
    assert_equal %Q|<div id="sampleimg" class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" width="120%" class="sample" />\n<p class="caption">\n図1.1: sample photo\n</p>\n</div>\n|, result
  end

  def test_image_with_tricky_id
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("123 あ_;",1)
      item.instance_eval{@path="./images/chap1-123 あ_;.png"}
      item
    end

    result = compile_block("//image[123 あ_;][sample photo]{\n//}\n")
    assert_equal %Q|<div id="id_123-_E3_81_82___3B" class="image">\n<img src="images/chap1-123 あ_;.png" alt="sample photo" />\n<p class="caption">\n図1.1: sample photo\n</p>\n</div>\n|, result
  end

  def test_indepimage
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//indepimage[sampleimg][sample photo]\n")
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" />\n<p class="caption">\n図: sample photo\n</p>\n</div>\n|, result
  end

  def test_indepimage_without_caption
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//indepimage[sampleimg]\n")
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="" />\n</div>\n|, result
  end

  def test_indepimage_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//indepimage[sampleimg][sample photo][scale=1.2]\n")
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" width="120%" />\n<p class="caption">\n図: sample photo\n</p>\n</div>\n|, result
  end

  def test_indepimage_with_metric2
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//indepimage[sampleimg][sample photo][scale=1.2, html::class=\"sample\",latex::ignore=params]\n")
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" width="120%" class="sample" />\n<p class="caption">\n図: sample photo\n</p>\n</div>\n|, result
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    result = compile_block("//indepimage[sampleimg][][scale=1.2]\n")
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="" width="120%" />\n</div>\n|, result
  end

  def test_list
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    result = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<div class="caption-code">\n<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>\n<pre class="list">test1\ntest1.5\n\ntest<i>2</i>\n</pre>\n</div>\n|, result
  end

  def test_list_pygments
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    begin
      require 'pygments'
    rescue LoadError
      return true
    end
    ReVIEW.book.config["pygments"] = true
    result = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")

    assert_equal %Q|<div class="caption-code">\n<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>\n<pre class="list">test1\ntest1.5\n\ntest<span style="color: #008000; font-weight: bold">&lt;i&gt;</span>2<span style="color: #008000; font-weight: bold">&lt;/i&gt;</span>\n</pre>\n</div>\n|, result
  end

  def test_emlist
    result = compile_block("//emlist{\nlineA\nlineB\n//}\n")
    assert_equal %Q|<div class="emlist-code">\n<pre class="emlist">lineA\nlineB\n</pre>\n</div>\n|, result
  end

  def test_emlist_caption
    result = compile_block("//emlist[cap1]{\nlineA\nlineB\n//}\n")
    assert_equal %Q|<div class="emlist-code">\n<p class="caption">cap1</p>\n<pre class="emlist">lineA\nlineB\n</pre>\n</div>\n|, result
  end

  def test_emlist_with_tab
    result = compile_block("//emlist{\n\tlineA\n\t\tlineB\n\tlineC\n//}\n")
    assert_equal %Q|<div class="emlist-code">\n<pre class="emlist">        lineA\n                lineB\n        lineC\n</pre>\n</div>\n|, result
  end

  def test_emlist_with_4tab
    @config["tabwidth"] = 4
    result = compile_block("//emlist{\n\tlineA\n\t\tlineB\n\tlineC\n//}\n")
    assert_equal %Q|<div class="emlist-code">\n<pre class="emlist">    lineA\n        lineB\n    lineC\n</pre>\n</div>\n|, result
  end

  def test_cmd
    result = compile_block("//cmd{\nlineA\nlineB\n//}\n")
    assert_equal %Q|<div class="cmd-code">\n<pre class="cmd">lineA\nlineB\n</pre>\n</div>\n|, result
  end

  def test_cmd_caption
    result = compile_block("//cmd[cap1]{\nlineA\nlineB\n//}\n")
    assert_equal %Q|<div class="cmd-code">\n<p class="caption">cap1</p>\n<pre class="cmd">lineA\nlineB\n</pre>\n</div>\n|, result
  end

  def test_bib
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    assert_equal %Q|<a href="./bib.html#bib-samplebib">[1]</a>|, compile_inline("@<bib>{samplebib}")
  end

  def test_bib_noramlized
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("sampleb=ib",1,"sample bib")
    end

    assert_equal %Q|<a href="./bib.html#bib-id_sample_3Dbib">[1]</a>|, compile_inline("@<bib>{sample=bib}")
  end

  def test_bibpaper
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    result = compile_block("//bibpaper[samplebib][sample bib @<b>{bold}]{\na\nb\n//}\n")
    assert_equal %Q|<div class=\"bibpaper\">\n<a id=\"bib-samplebib\">[1]</a> sample bib <b>bold</b>\n<p>ab</p></div>\n|, result
  end

  def test_bibpaper_normalized
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("sample=bib",1,"sample bib")
    end

    result = compile_block("//bibpaper[sample=bib][sample bib @<b>{bold}]{\na\nb\n//}\n")
    assert_equal %Q|<div class=\"bibpaper\">\n<a id=\"bib-id_sample_3Dbib\">[1]</a> sample bib <b>bold</b>\n<p>ab</p></div>\n|, result
  end

  def test_bibpaper_with_anchor
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    result = compile_block("//bibpaper[samplebib][sample bib @<href>{http://example.jp}]{\na\nb\n//}\n")
    assert_equal %Q|<div class=\"bibpaper\">\n<a id=\"bib-samplebib\">[1]</a> sample bib <a href=\"http://example.jp\" class=\"link\">http://example.jp</a>\n<p>ab</p></div>\n|, result
  end

  def column_helper(review)
    compile_block(review)
  end

  def test_column_1
    review =<<-EOS
===[column] prev column

inside prev column

===[column] test

inside column

===[/column]
EOS
    expect =<<-EOS
<div class="column">

<h3><a id="column-1"></a>prev column</h3>
<p>inside prev column</p>
</div>
<div class="column">

<h3><a id="column-2"></a>test</h3>
<p>inside column</p>
</div>
EOS
    assert_equal expect, column_helper(review)
  end

  def test_column_2
    review =<<-EOS
===[column] test

inside column

=== next level
EOS
    expect =<<-EOS
<div class="column">

<h3><a id="column-1"></a>test</h3>
<p>inside column</p>
</div>

<h3><a id="h1-0-1"></a>next level</h3>
EOS

    assert_equal expect, column_helper(review)
  end

  def test_column_3
    review =<<-EOS
===[column] test

inside column

===[/column_dummy]
EOS
    assert_raise(ReVIEW::CompileError) do
      column_helper(review)
    end
  end

  def test_column_ref
    review =<<-EOS
===[column]{foo} test

inside column

=== next level

this is @<column>{foo}.
EOS
    expect =<<-EOS
<div class="column">

<h3 id="foo"><a id="column-1"></a>test</h3>
<p>inside column</p>
</div>

<h3><a id="h1-0-1"></a>next level</h3>
<p>this is test.</p>
EOS

    assert_equal expect, column_helper(review)
  end


  def test_ul
    src =<<-EOS
  * AAA
  * BBB
EOS
    expect = "<ul>\n<li>AAA</li>\n<li>BBB</li>\n</ul>\n"
    result = compile_block(src)
    assert_equal expect, result
  end

  def test_ul_cont
    src =<<-EOS
  * AAA
    -AA
  * BBB
    -BB
EOS
    expect = "<ul>\n<li>AAA-AA</li>\n<li>BBB-BB</li>\n</ul>\n"
    result = compile_block(src)
    assert_equal expect, result
  end

  def test_ul_nest1
    src =<<-EOS
  * AAA
  ** AA
EOS

    expect =<<-EOS
<ul>
<li>AAA<ul>
<li>AA</li>
</ul>
</li>
</ul>
EOS
    result = compile_block(src)
    assert_equal expect, result
  end

  def test_ul_nest2
    src =<<-EOS
  * AAA
  ** AA
  * BBB
  ** BB
EOS

    expect =<<-EOS
<ul>
<li>AAA<ul>
<li>AA</li>
</ul>
</li>
<li>BBB<ul>
<li>BB</li>
</ul>
</li>
</ul>
EOS
    result = compile_block(src)
    assert_equal expect, result
  end

  def test_ul_nest3
    src =<<-EOS
  ** AAA
  * AA
  * BBB
  ** BB
EOS

    expect =<<-EOS
<ul>
<li><ul>
<li>AAA</li>
</ul>
</li>
<li>AA</li>
<li>BBB<ul>
<li>BB</li>
</ul>
</li>
</ul>
EOS
    result = compile_block(src)
    assert_equal expect, result
  end

  def test_ul_nest4
    src =<<-EOS
  * A
  ** AA
  *** AAA
  * B
  ** BB
EOS

    expect =<<-EOS
<ul>
<li>A<ul>
<li>AA<ul>
<li>AAA</li>
</ul>
</li>
</ul>
</li>
<li>B<ul>
<li>BB</li>
</ul>
</li>
</ul>
EOS
    result = compile_block(src)
    assert_equal expect, result
  end

  def test_ul_nest5
    src =<<-EOS
  * A
  ** AA
  **** AAAA
  * B
  ** BB
EOS

    expect =<<-EOS
<ul>
<li>A<ul>
<li>AA<ul>
<li><ul>
<li>AAAA</li>
</ul>
</li>
</ul>
</li>
</ul>
</li>
<li>B<ul>
<li>BB</li>
</ul>
</li>
</ul>
EOS
    result = compile_block(src)
    assert_equal expect, result
  end

  def test_ol
    src =<<-EOS
  3. AAA
  3. BBB
EOS

    expect =<<-EOS
<ol>
<li>AAA</li>
<li>BBB</li>
</ol>
EOS
    result = compile_block(src)
    assert_equal expect, result
  end

  def test_inline_raw0
    assert_equal "normal", compile_inline("@<raw>{normal}")
  end

  def test_inline_raw1
    assert_equal "body", compile_inline("@<raw>{|html|body}")
  end

  def test_inline_raw2
    assert_equal "body", compile_inline("@<raw>{|html, latex|body}")
  end

  def test_inline_raw3
    assert_equal "", compile_inline("@<raw>{|idgxml, latex|body}")
  end

  def test_inline_raw4
    assert_equal "|html body", compile_inline("@<raw>{|html body}")
  end

  def test_inline_raw5
    assert_equal "nor\nmal", compile_inline("@<raw>{|html|nor\\nmal}")
  end

  def test_block_raw0
    result = compile_block("//raw[<>!\"\\n& ]\n")
    expect = %Q(<>!\"\n& )
    assert_equal expect, result
  end

  def test_block_raw1
    result = compile_block("//raw[|html|<>!\"\\n& ]\n")
    expect = %Q(<>!\"\n& )
    assert_equal expect, result
  end

  def test_block_raw2
    result = compile_block("//raw[|html, latex|<>!\"\\n& ]\n")
    expect = %Q(<>!\"\n& )
    assert_equal expect, result
  end

  def test_block_raw3
    result = compile_block("//raw[|latex, idgxml|<>!\"\\n& ]\n")
    expect = ''
    assert_equal expect, result
  end

  def test_block_raw4
    result = compile_block("//raw[|html <>!\"\\n& ]\n")
    expect = %Q(|html <>!\"\n& )
    assert_equal expect.chomp, result
  end

  def test_inline_fn
    fn = Book::FootnoteIndex.parse(['//footnote[foo][bar\\a\\$buz]'])
    @chapter.instance_eval{@footnote_index=fn}
    result = compile_block("//footnote[foo][bar\\a\\$buz]\n")
    expect =<<-'EOS'
<div class="footnote" id="fn-foo"><p class="footnote">[<a href="#fnb-foo">*1</a>] bar\a\$buz</p></div>
EOS
    assert_equal expect, result
  end

  def test_inline_fn_with_tricky_id
    fn = Book::FootnoteIndex.parse(['//footnote[123 あ_;][bar\\a\\$buz]'])
    @chapter.instance_eval{@footnote_index=fn}
    result = compile_block("//footnote[123 あ_;][bar\\a\\$buz]\n")
    expect =<<-'EOS'
<div class="footnote" id="fn-id_123-_E3_81_82___3B"><p class="footnote">[<a href="#fnb-id_123-_E3_81_82___3B">*1</a>] bar\a\$buz</p></div>
EOS
    assert_equal expect, result
  end
end
