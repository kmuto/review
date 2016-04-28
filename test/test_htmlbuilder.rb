# encoding: utf-8

require 'test_helper'
require 'review'

class HTMLBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    ReVIEW::I18n.setup
    @builder = HTMLBuilder.new()
    @config = ReVIEW::Configure.values
    @config.merge!({
      "secnolevel" => 2, # for IDGXMLBuilder, HTMLBuilder
      "stylesheet" => nil, # for HTMLBuilder
      "htmlext" => "html",
    })
    @book = Book::Base.new(".")
    @book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
    I18n.setup("ja")
  end

  def test_xmlns_ops_prefix_epub3
    assert_equal "epub", @builder.xmlns_ops_prefix
  end

  def test_xmlns_ops_prefix_epub2
    @book.config["epubversion"] = 2
    assert_equal "ops", @builder.xmlns_ops_prefix
  end

  def test_headline_level1
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q|<h1 id="test"><a id="h1"></a><span class="secno">第1章　</span>this is test.</h1>\n|, actual
  end

  def test_headline_level1_postdef
    @chapter.instance_eval do
      def on_APPENDIX?
        true
      end
    end
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q|<h1 id="test"><a id="hA"></a><span class="secno">付録A　</span>this is test.</h1>\n|, actual
  end

  def test_headline_level2_postdef
    @chapter.instance_eval do
      def on_APPENDIX?
        true
      end
    end
    actual = compile_block("=={test} this is test.\n")
    assert_equal %Q|\n<h2 id="test"><a id="hA-1"></a><span class="secno">A.1　</span>this is test.</h2>\n|, actual
  end

  def test_headline_level1_postdef_roman
    @chapter.book.config["appendix_format"] = "roman"
    @chapter.instance_eval do
      def on_APPENDIX?
        true
      end
    end
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q|<h1 id="test"><a id="hI"></a><span class="secno">付録I　</span>this is test.</h1>\n|, actual
  end

  def test_headline_level2_postdef_roman
    @chapter.book.config["appendix_format"] = "roman"
    @chapter.instance_eval do
      def on_APPENDIX?
        true
      end
    end
    actual = compile_block("=={test} this is test.\n")
    assert_equal %Q|\n<h2 id="test"><a id="hI-1"></a><span class="secno">I.1　</span>this is test.</h2>\n|, actual
  end

  def test_headline_level1_postdef_alpha
    @chapter.book.config["appendix_format"] = "alpha"
    @chapter.instance_eval do
      def on_APPENDIX?
        true
      end
    end
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q|<h1 id="test"><a id="hA"></a><span class="secno">付録A　</span>this is test.</h1>\n|, actual
  end

  def test_headline_level2_postdef_alpha
    @chapter.book.config["appendix_format"] = "alpha"
    @chapter.instance_eval do
      def on_APPENDIX?
        true
      end
    end
    actual = compile_block("=={test} this is test.\n")
    assert_equal %Q|\n<h2 id="test"><a id="hA-1"></a><span class="secno">A.1　</span>this is test.</h2>\n|, actual
  end

  def test_headline_level1_postdef_alpha_i18n
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        @chapter.book.config["appendix_format"] = "alpha" # config is strong
        @chapter.instance_eval do
          def on_APPENDIX?
            true
          end
        end

        file = File.join(dir, "locale.yml") # i18n is weak
        File.open(file, "w"){|f| f.write("locale: ja\nappendix: 付録%pr")}
        I18n.setup("ja")
        actual = compile_block("={test} this is test.\n")
        assert_equal %Q|<h1 id="test"><a id="hA"></a><span class="secno">付録A　</span>this is test.</h1>\n|, actual

        actual = compile_block("=={test} this is test.\n")
        assert_equal %Q|\n<h2 id="test"><a id="hA-1"></a><span class="secno">A.1　</span>this is test.</h2>\n|, actual
      end
    end
  end

  def test_headline_level1_without_secno
    @book.config["secnolevel"] = 0
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q|<h1 id="test"><a id="h1"></a>this is test.</h1>\n|, actual
  end

  def test_headline_level1_with_tricky_id
    actual = compile_block("={123 あ_;} this is test.\n")
    assert_equal %Q|<h1 id="id_123-_E3_81_82___3B"><a id="h1"></a><span class="secno">第1章　</span>this is test.</h1>\n|, actual
  end

  def test_headline_level1_with_inlinetag
    actual = compile_block("={test} this @<b>{is} test.<&\">\n")
    assert_equal %Q|<h1 id="test"><a id="h1"></a><span class="secno">第1章　</span>this <b>is</b> test.&lt;&amp;&quot;&gt;</h1>\n|, actual
  end

  def test_headline_level2
    actual = compile_block("=={test} this is test.\n")
    assert_equal %Q|\n<h2 id="test"><a id="h1-1"></a><span class="secno">1.1　</span>this is test.</h2>\n|, actual
  end

  def test_headline_level3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q|\n<h3 id="test"><a id="h1-0-1"></a>this is test.</h3>\n|, actual
  end

  def test_headline_level3_with_secno
    @book.config["secnolevel"] = 3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q|\n<h3 id="test"><a id="h1-0-1"></a><span class="secno">1.0.1　</span>this is test.</h3>\n|, actual
  end

  def test_label
    actual = compile_block("//label[label_test]\n")
    assert_equal %Q|<a id="label_test"></a>\n|, actual
  end

  def test_label_with_tricky_id
    actual = compile_block("//label[123 あ_;]\n")
    assert_equal %Q|<a id="id_123-_E3_81_82___3B"></a>\n|, actual
  end

  def test_href
    actual = compile_inline("@<href>{http://github.com,GitHub}")
    assert_equal %Q|<a href="http://github.com" class="link">GitHub</a>|, actual
  end

  def test_href_without_label
    actual = compile_inline("@<href>{http://github.com}")
    assert_equal %Q|<a href="http://github.com" class="link">http://github.com</a>|, actual
  end

  def test_inline_href
    actual = compile_inline("@<href>{http://github.com,Git\\,Hub}")
    assert_equal %Q|<a href="http://github.com" class="link">Git,Hub</a>|, actual

    @book.config["epubmaker"] ||= {}
    @book.config["epubmaker"]["externallink"] = false
    actual = compile_inline("@<href>{http://github.com&q=1,Git\\,Hub}")
    assert_equal %Q|<a href="http://github.com&amp;q=1" class="link">Git,Hub</a>|, actual

    actual = compile_inline("@<href>{http://github.com&q=1}")
    assert_equal %Q|<a href="http://github.com&amp;q=1" class="link">http://github.com&amp;q=1</a>|, actual
  end

  def test_inline_href_epubmaker
    @book.config.maker = "epubmaker"
    actual = compile_inline("@<href>{http://github.com,Git\\,Hub}")
    assert_equal %Q|<a href="http://github.com" class="link">Git,Hub</a>|, actual

    @book.config["epubmaker"] ||= {}
    @book.config["epubmaker"]["externallink"] = false
    actual = compile_inline("@<href>{http://github.com&q=1,Git\\,Hub}")
    assert_equal %Q|Git,Hub（http://github.com&amp;q=1）|, actual

    actual = compile_inline("@<href>{http://github.com&q=1}")
    assert_equal %Q|http://github.com&amp;q=1|, actual

    @book.config["epubmaker"]["externallink"] = true
    actual = compile_inline("@<href>{http://github.com&q=1,Git\\,Hub}")
    assert_equal %Q|<a href="http://github.com&amp;q=1" class="link">Git,Hub</a>|, actual
    actual = compile_inline("@<href>{http://github.com&q=1}")
    assert_equal %Q|<a href="http://github.com&amp;q=1" class="link">http://github.com&amp;q=1</a>|, actual
  end

  def test_inline_raw
    actual = compile_inline("@<raw>{@<tt>{inline\\}}")
    assert_equal %Q|@<tt>{inline}|, actual
  end

  def test_inline_in_table
    actual = compile_block("//table{\n@<b>{1}\t@<i>{2}\n------------\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    assert_equal %Q|<div class="table">\n<table>\n<tr><th><b>1</b></th><th><i>2</i></th></tr>\n<tr><td><b>3</b></td><td><i>4</i>&lt;&gt;&amp;</td></tr>\n</table>\n</div>\n|, actual
  end

  def test_inline_br
    actual = compile_inline("@<br>{}")
    assert_equal %Q|<br />|, actual
  end

  def test_inline_i
    actual = compile_inline("test @<i>{inline test} test2")
    assert_equal %Q|test <i>inline test</i> test2|, actual
  end

  def test_inline_i_and_escape
    actual = compile_inline("test @<i>{inline<&;\\ test} test2")
    assert_equal %Q|test <i>inline&lt;&amp;;\\ test</i> test2|, actual
  end

  def test_inline_b
    actual = compile_inline("test @<b>{inline test} test2")
    assert_equal %Q|test <b>inline test</b> test2|, actual
  end

  def test_inline_b_and_escape
    actual = compile_inline("test @<b>{inline<&;\\ test} test2")
    assert_equal %Q|test <b>inline&lt;&amp;;\\ test</b> test2|, actual
  end

  def test_inline_tt
    actual = compile_inline("test @<tt>{inline test} test2")
    assert_equal %Q|test <code class="tt">inline test</code> test2|, actual
  end

  def test_inline_tti
    actual = compile_inline("test @<tti>{inline test} test2")
    assert_equal %Q|test <code class="tt"><i>inline test</i></code> test2|, actual
  end

  def test_inline_ttb
    actual = compile_inline("test @<ttb>{inline test} test2")
    assert_equal %Q|test <code class="tt"><b>inline test</b></code> test2|, actual
  end

  def test_inline_hd_chap
    def @chapter.headline_index
      items = [Book::HeadlineIndex::Item.new("chap1|test", [1, 1], "te_st")]
      Book::HeadlineIndex.new(items, self)
    end

    @config["secnolevel"] = 2
    actual = compile_inline("test @<hd>{chap1|test} test2")
    assert_equal %Q|test 「te_st」 test2|, actual

    @config["secnolevel"] = 3
    actual = compile_inline("test @<hd>{chap1|test} test2")
    assert_equal %Q|test 「1.1.1 te_st」 test2|, actual
  end

  def test_inline_hd_chap_postdef_roman
    @chapter.book.config["appendix_format"] = "roman"
    @chapter.instance_eval do
      def on_APPENDIX?
        true
      end
    end
    def @chapter.headline_index
      items = [Book::HeadlineIndex::Item.new("test", [1], "te_st")]
      Book::HeadlineIndex.new(items, self)
    end

    actual = compile_inline("test @<hd>{test} test2")
    assert_equal %Q|test 「I.1 te_st」 test2|, actual
  end

  def test_inline_hd_chap_postdef_alpha
    @chapter.book.config["appendix_format"] = "alpha"
    @chapter.instance_eval do
      def on_APPENDIX?
        true
      end
    end
    def @chapter.headline_index
      items = [Book::HeadlineIndex::Item.new("test", [1], "te_st")]
      Book::HeadlineIndex.new(items, self)
    end

    actual = compile_inline("test @<hd>{test} test2")
    assert_equal %Q|test 「A.1 te_st」 test2|, actual
  end

  def test_inline_uchar
    actual = compile_inline("test @<uchar>{2460} test2")
    assert_equal %Q|test &#x2460; test2|, actual
  end

  def test_inline_ruby
    actual = compile_inline("@<ruby>{粗雑,クルード}と思われているなら@<ruby>{繊細,テクニカル}にやり、繊細と思われているなら粗雑にやる。")
    assert_equal "<ruby>粗雑<rp>（</rp><rt>クルード</rt><rp>）</rp></ruby>と思われているなら<ruby>繊細<rp>（</rp><rt>テクニカル</rt><rp>）</rp></ruby>にやり、繊細と思われているなら粗雑にやる。", actual
  end

  def test_inline_ruby_comma
    actual = compile_inline("@<ruby>{foo\\, bar\\, buz,フー・バー・バズ}")
    assert_equal "<ruby>foo, bar, buz<rp>（</rp><rt>フー・バー・バズ</rt><rp>）</rp></ruby>", actual
  end

  def test_inline_ref
    actual = compile_inline("@<ref>{外部参照<>&}")
    assert_equal %Q|<a target='外部参照&lt;&gt;&amp;'>「●●　外部参照&lt;&gt;&amp;」</a>|, actual
  end

  def test_inline_mathml
    begin
      require 'math_ml'
      require "math_ml/symbol/character_reference"
    rescue LoadError
      return true
    end
    @config["mathml"] = true
    actual = compile_inline("@<m>{\\frac{-b \\pm \\sqrt{b^2 - 4ac\\}\\}{2a\\}}")
    @config["mathml"] = nil
    assert_equal "<span class=\"equation\"><math xmlns='http://www.w3.org/1998/Math/MathML' display='inline'><mfrac><mrow><mo stretchy='false'>-</mo><mi>b</mi><mo stretchy='false'>&#xb1;</mo><msqrt><mrow><msup><mi>b</mi><mn>2</mn></msup><mo stretchy='false'>-</mo><mn>4</mn><mi>a</mi><mi>c</mi></mrow></msqrt></mrow><mrow><mn>2</mn><mi>a</mi></mrow></mfrac></math></span>", actual
  end

  def test_inline_imgref
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg", 1, 'sample photo')
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block "@<imgref>{sampleimg}\n"
    expected = "<p>図1.1「sample photo」</p>\n"
    assert_equal expected, actual
  end

  def test_inline_imgref2
    def @chapter.image(id)
      item = Book::NumberlessImageIndex::Item.new("sampleimg", 1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block "@<imgref>{sampleimg}\n"
    expected = "<p>図1.1</p>\n"
    assert_equal expected, actual
  end


  def test_quote
    actual = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|<blockquote><p>foobar</p>\n<p>buz</p></blockquote>\n|, actual
  end

  def test_memo
    actual = compile_block("//memo[this is @<b>{test}<&>_]{\ntest1\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<div class="memo">\n<p class="caption">this is <b>test</b>&lt;&amp;&gt;_</p>\n<p>test1</p>\n<p>test<i>2</i></p>\n</div>\n|, actual
  end

  def test_noindent
    @builder.noindent
    actual = compile_block("foo\nbar\n\nfoo2\nbar2\n")
    assert_equal %Q|<p class="noindent">foobar</p>\n<p>foo2bar2</p>\n|, actual
  end

  def test_flushright
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|<p class="flushright">foobar</p>\n<p class="flushright">buz</p>\n|, actual
  end

  def test_centering
    actual = compile_block("//centering{\nfoo\nbar\n\nbuz\n//}\n")
    assert_equal %Q|<p class="center">foobar</p>\n<p class="center">buz</p>\n|, actual
  end

  def test_image
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//image[sampleimg][sample photo]{\n//}\n")
    assert_equal %Q|<div id="sampleimg" class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" />\n<p class="caption">\n図1.1: sample photo\n</p>\n</div>\n|, actual
  end

  def test_image_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2]{\n//}\n")
    assert_equal %Q|<div id="sampleimg" class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" class="width-120per" />\n<p class="caption">\n図1.1: sample photo\n</p>\n</div>\n|, actual
  end

  def test_image_with_metric2
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2,html::class=sample,latex::ignore=params]{\n//}\n")
    assert_equal %Q|<div id="sampleimg" class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" class="width-120per sample" />\n<p class="caption">\n図1.1: sample photo\n</p>\n</div>\n|, actual
  end

  def test_image_with_tricky_id
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("123 あ_;",1)
      item.instance_eval{@path="./images/chap1-123 あ_;.png"}
      item
    end

    actual = compile_block("//image[123 あ_;][sample photo]{\n//}\n")
    assert_equal %Q|<div id="id_123-_E3_81_82___3B" class="image">\n<img src="images/chap1-123 あ_;.png" alt="sample photo" />\n<p class="caption">\n図1.1: sample photo\n</p>\n</div>\n|, actual
  end

  def test_indepimage
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo]\n")
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" />\n<p class="caption">\n図: sample photo\n</p>\n</div>\n|, actual
  end

  def test_indepimage_without_caption
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//indepimage[sampleimg]\n")
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="" />\n</div>\n|, actual
  end

  def test_indepimage_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo][scale=1.2]\n")
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" class="width-120per" />\n<p class="caption">\n図: sample photo\n</p>\n</div>\n|, actual
  end

  def test_indepimage_with_metric2
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo][scale=1.2, html::class=\"sample\",latex::ignore=params]\n")
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="sample photo" class="width-120per sample" />\n<p class="caption">\n図: sample photo\n</p>\n</div>\n|, actual
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//indepimage[sampleimg][][scale=1.2]\n")
    assert_equal %Q|<div class="image">\n<img src="images/chap1-sampleimg.png" alt="" class="width-120per" />\n</div>\n|, actual
  end

  def test_dlist
    actual = compile_block(": foo\n  foo.\n  bar.\n")
    assert_equal %Q|<dl>\n<dt>foo</dt>\n<dd>foo.bar.</dd>\n</dl>\n|, actual
  end

  def test_dlist_with_bracket
    actual = compile_block(": foo[bar]\n    foo.\n    bar.\n")
    assert_equal %Q|<dl>\n<dt>foo[bar]</dt>\n<dd>foo.bar.</dd>\n</dl>\n|, actual
  end

  def test_dlist_with_comment
    source = ": title\n  body\n\#@ comment\n\#@ comment\n: title2\n  body2\n"
    actual = compile_block(source)
    assert_equal %Q|<dl>\n<dt>title</dt>\n<dd>body</dd>\n<dt>title2</dt>\n<dd>body2</dd>\n</dl>\n|, actual
  end

  def test_list
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    assert_equal %Q|<div class="caption-code">\n<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>\n<pre class="list">test1\ntest1.5\n\ntest<i>2</i>\n</pre>\n</div>\n|, actual
  end

  def test_list_pygments
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    begin
      require 'pygments'
    rescue LoadError
      $stderr.puts "skip test_list_pygments_lang (cannot find pygments.rb)"
      return true
    end
    @book.config["highlight"] = {}
    @book.config["highlight"]["html"] = "pygments"
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")

    assert_equal %Q|<div class="caption-code">\n<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>\n<pre class="list">test1\ntest1.5\n\ntest&lt;i&gt;2&lt;/i&gt;\n</pre>\n</div>\n|, actual
  end

  def test_list_pygments_lang
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    begin
      require 'pygments'
    rescue LoadError
      $stderr.puts "skip test_list_pygments_lang (cannot find pygments.rb)"
      return true
    end
    @book.config["highlight"] = {}
    @book.config["highlight"]["html"] = "pygments"
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_][ruby]{\ndef foo(a1, a2=:test)\n  (1..3).times{|i| a.include?(:foo)}\n  return true\nend\n\n//}\n")

    assert_equal %Q|<div class=\"caption-code\">\n<p class=\"caption\">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>\n| +
                 %Q|<pre class=\"list\"><span style=\"color: #008000; font-weight: bold\">def</span> <span style=\"color: #0000FF\">foo</span>(a1, a2<span style=\"color: #666666\">=</span><span style=\"color: #19177C\">:test</span>)\n| +
                 %Q|  (<span style=\"color: #666666\">1.</span>.<span style=\"color: #666666\">3</span>)<span style=\"color: #666666\">.</span>times{<span style=\"color: #666666\">\|</span>i<span style=\"color: #666666\">\|</span> a<span style=\"color: #666666\">.</span>include?(<span style=\"color: #19177C\">:foo</span>)}\n| +
                 %Q|  <span style=\"color: #008000; font-weight: bold\">return</span> <span style=\"color: #008000\">true</span>\n| +
                 %Q|<span style=\"color: #008000; font-weight: bold\">end</span>\n| +
                 %Q|</pre>\n| +
                 %Q|</div>\n|, actual
  end

  def test_list_pygments_nulllang
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    begin
      require 'pygments'
    rescue LoadError
      $stderr.puts "skip test_list_pygments_nulllang (cannot find pygments.rb)"
      return true
    end
    @book.config["highlight"] = {}
    @book.config["highlight"]["html"] = "pygments"
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_][]{\ndef foo(a1, a2=:test)\n  (1..3).times{|i| a.include?(:foo)}\n  return true\nend\n\n//}\n")

    assert_equal "<div class=\"caption-code\">\n<p class=\"caption\">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>\n<pre class=\"list\">def foo(a1, a2=:test)\n  (1..3).times{|i| a.include?(:foo)}\n  return true\nend\n</pre>\n</div>\n", actual
  end

  def test_listnum
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end

    @book.config["highlight"] = false
    actual = compile_block(<<-EOS)
//listnum[samplelist][this is @<b>{test}<&>_][ruby]{
def foo(a1, a2=:test)
  (1..3).times{|i| a.include?(:foo)}
  return true
end
//}
EOS

    expected =<<-EOS
<div class="code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<pre class="list"> 1: def foo(a1, a2=:test)
 2:   (1..3).times{|i| a.include?(:foo)}
 3:   return true
 4: end
</pre>
</div>
EOS

    assert_equal expected, actual
  end

  def test_listnum_pygments_lang
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    begin
      require 'pygments'
    rescue LoadError
      $stderr.puts "skip test_listnum_pygments_lang (cannot find pygments.rb)"
      return true
    end
    @book.config["highlight"] = {}
    @book.config["highlight"]["html"] = "pygments"
    actual = compile_block("//listnum[samplelist][this is @<b>{test}<&>_][ruby]{\ndef foo(a1, a2=:test)\n  (1..3).times{|i| a.include?(:foo)}\n  return true\nend\n\n//}\n")

    assert_equal "<div class=\"code\">\n<p class=\"caption\">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>\n<div class=\"highlight\" style=\"background: #f8f8f8\"><pre style=\"line-height: 125%\"><span style=\"background-color: #f0f0f0; padding: 0 5px 0 5px\">1</span> <span style=\"color: #008000; font-weight: bold\">def</span> <span style=\"color: #0000FF\">foo</span>(a1, a2<span style=\"color: #666666\">=</span><span style=\"color: #19177C\">:test</span>)\n<span style=\"background-color: #f0f0f0; padding: 0 5px 0 5px\">2</span>   (<span style=\"color: #666666\">1.</span>.<span style=\"color: #666666\">3</span>)<span style=\"color: #666666\">.</span>times{<span style=\"color: #666666\">|</span>i<span style=\"color: #666666\">|</span> a<span style=\"color: #666666\">.</span>include?(<span style=\"color: #19177C\">:foo</span>)}\n<span style=\"background-color: #f0f0f0; padding: 0 5px 0 5px\">3</span>   <span style=\"color: #008000; font-weight: bold\">return</span> <span style=\"color: #008000\">true</span>\n<span style=\"background-color: #f0f0f0; padding: 0 5px 0 5px\">4</span> <span style=\"color: #008000; font-weight: bold\">end</span>\n</pre></div>\n</div>\n", actual
  end

  def test_listnum_pygments_lang_without_lang
    def @chapter.list(id)
      Book::ListIndex::Item.new("samplelist",1)
    end
    begin
      require 'pygments'
    rescue LoadError
      $stderr.puts "skip test_listnum_pygments_lang (cannot find pygments.rb)"
      return true
    end
    @book.config["highlight"] = {}
    @book.config["highlight"]["html"] = "pygments"
    @book.config["highlight"]["lang"] = "ruby"
    actual = compile_block("//listnum[samplelist][this is @<b>{test}<&>_]{\ndef foo(a1, a2=:test)\n  (1..3).times{|i| a.include?(:foo)}\n  return true\nend\n\n//}\n")

    assert_equal "<div class=\"code\">\n<p class=\"caption\">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>\n<div class=\"highlight\" style=\"background: #f8f8f8\"><pre style=\"line-height: 125%\"><span style=\"background-color: #f0f0f0; padding: 0 5px 0 5px\">1</span> <span style=\"color: #008000; font-weight: bold\">def</span> <span style=\"color: #0000FF\">foo</span>(a1, a2<span style=\"color: #666666\">=</span><span style=\"color: #19177C\">:test</span>)\n<span style=\"background-color: #f0f0f0; padding: 0 5px 0 5px\">2</span>   (<span style=\"color: #666666\">1.</span>.<span style=\"color: #666666\">3</span>)<span style=\"color: #666666\">.</span>times{<span style=\"color: #666666\">|</span>i<span style=\"color: #666666\">|</span> a<span style=\"color: #666666\">.</span>include?(<span style=\"color: #19177C\">:foo</span>)}\n<span style=\"background-color: #f0f0f0; padding: 0 5px 0 5px\">3</span>   <span style=\"color: #008000; font-weight: bold\">return</span> <span style=\"color: #008000\">true</span>\n<span style=\"background-color: #f0f0f0; padding: 0 5px 0 5px\">4</span> <span style=\"color: #008000; font-weight: bold\">end</span>\n</pre></div>\n</div>\n", actual
  end


  def test_emlist
    actual = compile_block("//emlist{\nlineA\nlineB\n//}\n")
    assert_equal %Q|<div class="emlist-code">\n<pre class="emlist">lineA\nlineB\n</pre>\n</div>\n|, actual
  end

  def test_emlist_pygments_lang
    begin
      require 'pygments'
    rescue LoadError
      $stderr.puts "skip test_emlist_pygments_lang (cannot find pygments.rb)"
      return true
    end
    @book.config["highlight"] = {}
    @book.config["highlight"]["html"] = "pygments"
    actual = compile_block("//emlist[][sql]{\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n//}\n")
    assert_equal "<div class=\"emlist-code\">\n<pre class=\"emlist\"><span style=\"color: #008000; font-weight: bold\">SELECT</span> <span style=\"color: #008000; font-weight: bold\">COUNT</span>(<span style=\"color: #666666\">*</span>) <span style=\"color: #008000; font-weight: bold\">FROM</span> tests <span style=\"color: #008000; font-weight: bold\">WHERE</span> tests.<span style=\"color: #008000; font-weight: bold\">no</span> <span style=\"color: #666666\">&gt;</span> <span style=\"color: #666666\">10</span> <span style=\"color: #008000; font-weight: bold\">AND</span> test.name <span style=\"color: #008000; font-weight: bold\">LIKE</span> <span style=\"color: #BA2121\">&#39;ABC%&#39;</span>\n</pre>\n</div>\n", actual
  end

  def test_emlist_caption
    actual = compile_block("//emlist[cap1]{\nlineA\nlineB\n//}\n")
    assert_equal %Q|<div class="emlist-code">\n<p class="caption">cap1</p>\n<pre class="emlist">lineA\nlineB\n</pre>\n</div>\n|, actual
  end

  def test_emlist_with_tab
    actual = compile_block("//emlist{\n\tlineA\n\t\tlineB\n\tlineC\n//}\n")
    assert_equal %Q|<div class="emlist-code">\n<pre class="emlist">        lineA\n                lineB\n        lineC\n</pre>\n</div>\n|, actual
  end

  def test_emlistnum
    @book.config["highlight"] = false
    actual = compile_block("//emlistnum{\nlineA\nlineB\n//}\n")
    expected =<<-EOS
<div class="emlistnum-code">
<pre class="emlist"> 1: lineA
 2: lineB
</pre>
</div>
EOS
    assert_equal expected, actual
  end

  def test_emlist_with_4tab
    @config["tabwidth"] = 4
    actual = compile_block("//emlist{\n\tlineA\n\t\tlineB\n\tlineC\n//}\n")
    assert_equal %Q|<div class="emlist-code">\n<pre class="emlist">    lineA\n        lineB\n    lineC\n</pre>\n</div>\n|, actual
  end

  def test_cmd
    actual = compile_block("//cmd{\nlineA\nlineB\n//}\n")
    assert_equal %Q|<div class="cmd-code">\n<pre class="cmd">lineA\nlineB\n</pre>\n</div>\n|, actual
  end

  def test_cmd_pygments
    begin
      require 'pygments'
    rescue LoadError
      return true
    end
    @book.config["highlight"] = {}
    @book.config["highlight"]["html"] = "pygments"
    actual = compile_block("//cmd{\nlineA\nlineB\n//}\n")
    assert_equal "<div class=\"cmd-code\">\n<pre class=\"cmd\"><span style=\"color: #888888\">lineA</span>\n<span style=\"color: #888888\">lineB</span>\n</pre>\n</div>\n", actual
  end

  def test_cmd_caption
    actual = compile_block("//cmd[cap1]{\nlineA\nlineB\n//}\n")
    assert_equal %Q|<div class="cmd-code">\n<p class="caption">cap1</p>\n<pre class="cmd">lineA\nlineB\n</pre>\n</div>\n|, actual
  end

  def test_bib
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    assert_equal %Q|<a href="bib.html#bib-samplebib">[1]</a>|, compile_inline("@<bib>{samplebib}")
  end

  def test_bib_noramlized
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("sampleb=ib",1,"sample bib")
    end

    assert_equal %Q|<a href="bib.html#bib-id_sample_3Dbib">[1]</a>|, compile_inline("@<bib>{sample=bib}")
  end

  def test_bib_htmlext
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    @config["htmlext"] = "xhtml"
    assert_equal %Q|<a href="bib.xhtml#bib-samplebib">[1]</a>|, compile_inline("@<bib>{samplebib}")
  end

  def test_bibpaper
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    actual = compile_block("//bibpaper[samplebib][sample bib @<b>{bold}]{\na\nb\n//}\n")
    assert_equal %Q|<div class=\"bibpaper\">\n<a id=\"bib-samplebib\">[1]</a> sample bib <b>bold</b>\n<p>ab</p></div>\n|, actual
  end

  def test_bibpaper_normalized
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("sample=bib",1,"sample bib")
    end

    actual = compile_block("//bibpaper[sample=bib][sample bib @<b>{bold}]{\na\nb\n//}\n")
    assert_equal %Q|<div class=\"bibpaper\">\n<a id=\"bib-id_sample_3Dbib\">[1]</a> sample bib <b>bold</b>\n<p>ab</p></div>\n|, actual
  end

  def test_bibpaper_with_anchor
    def @chapter.bibpaper(id)
      Book::BibpaperIndex::Item.new("samplebib",1,"sample bib")
    end

    actual = compile_block("//bibpaper[samplebib][sample bib @<href>{http://example.jp}]{\na\nb\n//}\n")
    assert_equal %Q|<div class=\"bibpaper\">\n<a id=\"bib-samplebib\">[1]</a> sample bib <a href=\"http://example.jp\" class=\"link\">http://example.jp</a>\n<p>ab</p></div>\n|, actual
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
    expected =<<-EOS
<div class="column">

<h3><a id="column-1"></a>prev column</h3>
<p>inside prev column</p>
</div>
<div class="column">

<h3><a id="column-2"></a>test</h3>
<p>inside column</p>
</div>
EOS
    assert_equal expected, column_helper(review)
  end

  def test_column_2
    review =<<-EOS
===[column] test

inside column

=== next level
EOS
    expected =<<-EOS
<div class="column">

<h3><a id="column-1"></a>test</h3>
<p>inside column</p>
</div>

<h3><a id="h1-0-1"></a>next level</h3>
EOS

    assert_equal expected, column_helper(review)
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
    expected =<<-EOS
<div class="column">

<h3 id="foo"><a id="column-1"></a>test</h3>
<p>inside column</p>
</div>

<h3><a id="h1-0-1"></a>next level</h3>
<p>this is コラム「test」.</p>
EOS

    assert_equal expected, column_helper(review)
  end

  def test_column_in_aother_chapter_ref
    def @chapter.column_index
      items = [Book::ColumnIndex::Item.new("chap1|column", 1, "column_cap")]
      Book::ColumnIndex.new(items)
    end

    actual = compile_inline("test @<column>{chap1|column} test2")
    expected = "test コラム「column_cap」 test2"
    assert_equal expected, actual
  end

  def test_ul
    src =<<-EOS
  * AAA
  * BBB
EOS
    expected = "<ul>\n<li>AAA</li>\n<li>BBB</li>\n</ul>\n"
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_cont
    src =<<-EOS
  * AAA
    -AA
  * BBB
    -BB
EOS
    expected = "<ul>\n<li>AAA-AA</li>\n<li>BBB-BB</li>\n</ul>\n"
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest1
    src =<<-EOS
  * AAA
  ** AA
EOS

    expected =<<-EOS
<ul>
<li>AAA<ul>
<li>AA</li>
</ul>
</li>
</ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest2
    src =<<-EOS
  * AAA
  ** AA
  * BBB
  ** BB
EOS

    expected =<<-EOS
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
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest3
    src =<<-EOS
  ** AAA
  * AA
  * BBB
  ** BB
EOS

    expected =<<-EOS
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
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest4
    src =<<-EOS
  * A
  ** AA
  *** AAA
  * B
  ** BB
EOS

    expected =<<-EOS
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
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest5
    src =<<-EOS
  * A
  ** AA
  **** AAAA
  * B
  ** BB
EOS

    expected =<<-EOS
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
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ol
    src =<<-EOS
  3. AAA
  3. BBB
EOS

    expected =<<-EOS
<ol>
<li>AAA</li>
<li>BBB</li>
</ol>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
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
    actual = compile_block("//raw[<>!\"\\n& ]\n")
    expected = %Q(<>!\"\n& )
    assert_equal expected, actual
  end

  def test_block_raw1
    actual = compile_block("//raw[|html|<>!\"\\n& ]\n")
    expected = %Q(<>!\"\n& )
    assert_equal expected, actual
  end

  def test_block_raw2
    actual = compile_block("//raw[|html, latex|<>!\"\\n& ]\n")
    expected = %Q(<>!\"\n& )
    assert_equal expected, actual
  end

  def test_block_raw3
    actual = compile_block("//raw[|latex, idgxml|<>!\"\\n& ]\n")
    expected = ''
    assert_equal expected, actual
  end

  def test_block_raw4
    actual = compile_block("//raw[|html <>!\"\\n& ]\n")
    expected = %Q(|html <>!\"\n& )
    assert_equal expected, actual
  end

  def test_inline_fn
    fn = Book::FootnoteIndex.parse(['//footnote[foo][bar\\a\\$buz]'])
    @chapter.instance_eval{@footnote_index=fn}
    actual = compile_block("//footnote[foo][bar\\a\\$buz]\n")
    expected =<<-'EOS'
<div class="footnote" epub:type="footnote" id="fn-foo"><p class="footnote">[*1] bar\a\$buz</p></div>
EOS
    assert_equal expected, actual
  end

  def test_inline_fn_with_tricky_id
    fn = Book::FootnoteIndex.parse(['//footnote[123 あ_;][bar\\a\\$buz]'])
    @chapter.instance_eval{@footnote_index=fn}
    actual = compile_block("//footnote[123 あ_;][bar\\a\\$buz]\n")
    expected =<<-'EOS'
<div class="footnote" epub:type="footnote" id="fn-id_123-_E3_81_82___3B"><p class="footnote">[*1] bar\a\$buz</p></div>
EOS
    assert_equal expected, actual
  end

  def test_inline_hd
    book = ReVIEW::Book::Base.load
    book.catalog = ReVIEW::Catalog.new({"CHAPS"=>%w(ch1.re ch2.re)})
    io1 = StringIO.new("= test1\n\nfoo\n\n== test1-1\n\nbar\n\n== test1-2\n\nbar\n\n")
    io2 = StringIO.new("= test2\n\nfoo\n\n== test2-1\n\nbar\n\n== test2-2\n\nbar\n\n")
    chap1 = ReVIEW::Book::Chapter.new(book, 1, 'ch1', 'ch1.re', io1)
    chap2 = ReVIEW::Book::Chapter.new(book, 2, 'ch2', 'ch2.re', io2)
    book.parts = [ReVIEW::Book::Part.new(self, nil, [chap1, chap2])]
    builder = ReVIEW::HTMLBuilder.new
    comp = ReVIEW::Compiler.new(builder)
    builder.bind(comp, chap2, nil)
    hd = builder.inline_hd("ch1|test1-1")
    assert_equal "「1.1 test1-1」", hd
  end

  def test_inline_hd_for_part
    book = ReVIEW::Book::Base.load
    book.catalog = ReVIEW::Catalog.new({"CHAPS"=>%w(ch1.re ch2.re)})
    io1 = StringIO.new("= test1\n\nfoo\n\n== test1-1\n\nbar\n\n== test1-2\n\nbar\n\n")
    io2 = StringIO.new("= test2\n\nfoo\n\n== test2-1\n\nbar\n\n== test2-2\n\nbar\n\n")
    io_p1 = StringIO.new("= part1\n\nfoo\n\n== part1-1\n\nbar\n\n== part1-2\n\nbar\n\n")
    chap1 = ReVIEW::Book::Chapter.new(book, 1, 'ch1', 'ch1.re', io1)
    chap2 = ReVIEW::Book::Chapter.new(book, 2, 'ch2', 'ch2.re', io2)
    book.parts = [ReVIEW::Book::Part.new(self, 1, [chap1, chap2], "part1.re", io_p1)]
    builder = ReVIEW::HTMLBuilder.new
    comp = ReVIEW::Compiler.new(builder)
    builder.bind(comp, chap2, nil)
    hd = builder.inline_hd("part1|part1-1")
    assert_equal "「1.1 part1-1」", hd
  end

  def test_table
    actual = compile_block("//table{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    assert_equal %Q|<div class="table">\n<table>\n<tr><th>aaa</th><th>bbb</th></tr>\n<tr><td>ccc</td><td>ddd&lt;&gt;&amp;</td></tr>\n</table>\n</div>\n|,
                 actual
  end

  def test_imgtable
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1, 'sample img')
      item.instance_eval{@path="./images/chap1-sampleimg.png"}
      item
    end

    actual = compile_block("//imgtable[sampleimg][test for imgtable]{\n//}\n")
    expected = %Q|<div id="sampleimg" class="imgtable image">\n<p class="caption">表1.1: test for imgtable</p>\n<img src="images/chap1-sampleimg.png" alt="test for imgtable" />\n</div>\n|
    assert_equal expected, actual
  end

  def test_major_blocks
    actual = compile_block("//note{\nA\n\nB\n//}\n//note[caption]{\nA\n//}")
    expected = %Q(<div class="note">\n<p>A</p>\n<p>B</p>\n</div>\n<div class="note">\n<p class="caption">caption</p>\n<p>A</p>\n</div>\n)
    assert_equal expected, actual

    actual = compile_block("//memo{\nA\n\nB\n//}\n//memo[caption]{\nA\n//}")
    expected = %Q(<div class="memo">\n<p>A</p>\n<p>B</p>\n</div>\n<div class="memo">\n<p class="caption">caption</p>\n<p>A</p>\n</div>\n)
    assert_equal expected, actual

    actual = compile_block("//info{\nA\n\nB\n//}\n//info[caption]{\nA\n//}")
    expected = %Q(<div class="info">\n<p>A</p>\n<p>B</p>\n</div>\n<div class="info">\n<p class="caption">caption</p>\n<p>A</p>\n</div>\n)
    assert_equal expected, actual

    actual = compile_block("//important{\nA\n\nB\n//}\n//important[caption]{\nA\n//}")
    expected = %Q(<div class="important">\n<p>A</p>\n<p>B</p>\n</div>\n<div class="important">\n<p class="caption">caption</p>\n<p>A</p>\n</div>\n)
    assert_equal expected, actual

    actual = compile_block("//caution{\nA\n\nB\n//}\n//caution[caption]{\nA\n//}")
    expected = %Q(<div class="caution">\n<p>A</p>\n<p>B</p>\n</div>\n<div class="caution">\n<p class="caption">caption</p>\n<p>A</p>\n</div>\n)
    assert_equal expected, actual

    actual = compile_block("//notice{\nA\n\nB\n//}\n//notice[caption]{\nA\n//}")
    expected = %Q(<div class="notice">\n<p>A</p>\n<p>B</p>\n</div>\n<div class="notice">\n<p class="caption">caption</p>\n<p>A</p>\n</div>\n)
    assert_equal expected, actual

    actual = compile_block("//warning{\nA\n\nB\n//}\n//warning[caption]{\nA\n//}")
    expected = %Q(<div class="warning">\n<p>A</p>\n<p>B</p>\n</div>\n<div class="warning">\n<p class="caption">caption</p>\n<p>A</p>\n</div>\n)
    assert_equal expected, actual

    actual = compile_block("//tip{\nA\n\nB\n//}\n//tip[caption]{\nA\n//}")
    expected = %Q(<div class="tip">\n<p>A</p>\n<p>B</p>\n</div>\n<div class="tip">\n<p class="caption">caption</p>\n<p>A</p>\n</div>\n)
    assert_equal expected, actual
  end

end
