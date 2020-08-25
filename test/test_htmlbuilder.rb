require 'test_helper'
require 'book_test_helper'
require 'review'

class HTMLBuidlerTest < Test::Unit::TestCase
  include ReVIEW
  include BookTestHelper

  def setup
    ReVIEW::I18n.setup
    @builder = HTMLBuilder.new
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['stylesheet'] = nil
    @config['htmlext'] = 'html'
    @config['epubmaker'] = {}
    @book = Book::Base.new('.')
    @book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
    I18n.setup('ja')
  end

  def test_xmlns_ops_prefix_epub3
    assert_equal 'epub', @builder.xmlns_ops_prefix
  end

  def test_xmlns_ops_prefix_epub2
    @book.config['epubversion'] = 2
    assert_equal 'ops', @builder.xmlns_ops_prefix
  end

  def test_headline_level1
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q(<h1 id="test"><a id="h1"></a><span class="secno">第1章　</span>this is test.</h1>\n), actual
  end

  def test_headline_level1_postdef
    @chapter.instance_eval do
      def on_appendix?
        true
      end
    end
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q(<h1 id="test"><a id="hA"></a><span class="secno">付録A　</span>this is test.</h1>\n), actual
  end

  def test_headline_level2_postdef
    @chapter.instance_eval do
      def on_appendix?
        true
      end
    end
    actual = compile_block("=={test} this is test.\n")
    assert_equal %Q(\n<h2 id="test"><a id="hA-1"></a><span class="secno">A.1　</span>this is test.</h2>\n), actual
  end

  def test_headline_postdef_roman
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, 'locale.yml')
        File.open(file, 'w') { |f| f.write "locale: ja\nappendix: 付録%pR" }
        I18n.setup('ja')
        @chapter.instance_eval do
          def on_appendix?
            true
          end
        end

        actual = compile_block("={test} this is test.\n")
        assert_equal %Q(<h1 id="test"><a id="hI"></a><span class="secno">付録I　</span>this is test.</h1>\n), actual

        actual = compile_block("=={test} this is test.\n")
        assert_equal %Q(\n<h2 id="test"><a id="hI-1"></a><span class="secno">I.1　</span>this is test.</h2>\n), actual
      end
    end
  end

  def test_headline_postdef_alpha
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, 'locale.yml')
        File.open(file, 'w') { |f| f.write "locale: ja\nappendix: 付録%pA" }
        I18n.setup('ja')
        @chapter.instance_eval do
          def on_appendix?
            true
          end
        end

        actual = compile_block("={test} this is test.\n")
        assert_equal %Q(<h1 id="test"><a id="hA"></a><span class="secno">付録A　</span>this is test.</h1>\n), actual

        actual = compile_block("=={test} this is test.\n")
        assert_equal %Q(\n<h2 id="test"><a id="hA-1"></a><span class="secno">A.1　</span>this is test.</h2>\n), actual
      end
    end
  end

  def test_headline_level1_without_secno
    @book.config['secnolevel'] = 0
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q(<h1 id="test"><a id="h1"></a>this is test.</h1>\n), actual
  end

  def test_headline_level1_with_tricky_id
    actual = compile_block("={123 あ_;} this is test.\n")
    assert_equal %Q(<h1 id="id_123-_E3_81_82___3B"><a id="h1"></a><span class="secno">第1章　</span>this is test.</h1>\n), actual
  end

  def test_headline_level1_with_inlinetag
    actual = compile_block(%Q(={test} this @<b>{is} test.<&">\n))
    assert_equal %Q(<h1 id="test"><a id="h1"></a><span class="secno">第1章　</span>this <b>is</b> test.&lt;&amp;&quot;&gt;</h1>\n), actual
  end

  def test_headline_level2
    actual = compile_block("=={test} this is test.\n")
    assert_equal %Q(\n<h2 id="test"><a id="h1-1"></a><span class="secno">1.1　</span>this is test.</h2>\n), actual
  end

  def test_headline_level3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q(\n<h3 id="test"><a id="h1-0-1"></a>this is test.</h3>\n), actual
  end

  def test_headline_level3_with_secno
    @book.config['secnolevel'] = 3
    actual = compile_block("==={test} this is test.\n")
    assert_equal %Q(\n<h3 id="test"><a id="h1-0-1"></a><span class="secno">1.0.1　</span>this is test.</h3>\n), actual
  end

  def test_label
    actual = compile_block("//label[label_test]\n")
    assert_equal %Q(<a id="label_test"></a>\n), actual
  end

  def test_label_with_tricky_id
    actual = compile_block("//label[123 あ_;]\n")
    assert_equal %Q(<a id="id_123-_E3_81_82___3B"></a>\n), actual
  end

  def test_href
    actual = compile_inline('@<href>{http://github.com,GitHub}')
    assert_equal %Q(<a href="http://github.com" class="link">GitHub</a>), actual
  end

  def test_href_without_label
    actual = compile_inline('@<href>{http://github.com}')
    assert_equal %Q(<a href="http://github.com" class="link">http://github.com</a>), actual
  end

  def test_inline_href
    actual = compile_inline('@<href>{http://github.com,Git\\,Hub}')
    assert_equal %Q(<a href="http://github.com" class="link">Git,Hub</a>), actual

    @book.config['epubmaker'] ||= {}
    @book.config['epubmaker']['externallink'] = false
    actual = compile_inline('@<href>{http://github.com&q=1,Git\\,Hub}')
    assert_equal %Q(<a href="http://github.com&amp;q=1" class="link">Git,Hub</a>), actual

    actual = compile_inline('@<href>{http://github.com&q=1}')
    assert_equal %Q(<a href="http://github.com&amp;q=1" class="link">http://github.com&amp;q=1</a>), actual
  end

  def test_inline_href_epubmaker
    @book.config.maker = 'epubmaker'
    actual = compile_inline('@<href>{http://github.com,Git\\,Hub}')
    assert_equal %Q(<a href="http://github.com" class="link">Git,Hub</a>), actual

    @book.config['epubmaker'] ||= {}
    @book.config['epubmaker']['externallink'] = false
    actual = compile_inline('@<href>{http://github.com&q=1,Git\\,Hub}')
    assert_equal 'Git,Hub（http://github.com&amp;q=1）', actual

    actual = compile_inline('@<href>{http://github.com&q=1}')
    assert_equal 'http://github.com&amp;q=1', actual

    @book.config['epubmaker']['externallink'] = true
    actual = compile_inline('@<href>{http://github.com&q=1,Git\\,Hub}')
    assert_equal %Q(<a href="http://github.com&amp;q=1" class="link">Git,Hub</a>), actual
    actual = compile_inline('@<href>{http://github.com&q=1}')
    assert_equal %Q(<a href="http://github.com&amp;q=1" class="link">http://github.com&amp;q=1</a>), actual
  end

  def test_inline_raw
    actual = compile_inline('@<raw>{@<tt>{inline\\}}')
    assert_equal '@<tt>{inline}', actual
  end

  def test_inline_in_table
    actual = compile_block("//table{\n@<b>{1}\t@<i>{2}\n------------\n@<b>{3}\t@<i>{4}<>&\n//}\n")
    expected = <<-EOS
<div class="table">
<table>
<tr><th><b>1</b></th><th><i>2</i></th></tr>
<tr><td><b>3</b></td><td><i>4</i>&lt;&gt;&amp;</td></tr>
</table>
</div>
EOS
    assert_equal expected, actual
  end

  def test_inline_br
    actual = compile_inline('@<br>{}')
    assert_equal '<br />', actual
  end

  def test_inline_i
    actual = compile_inline('test @<i>{inline test} test2')
    assert_equal 'test <i>inline test</i> test2', actual
  end

  def test_inline_i_and_escape
    actual = compile_inline('test @<i>{inline<&;\\ test} test2')
    assert_equal 'test <i>inline&lt;&amp;;\\ test</i> test2', actual
  end

  def test_inline_b
    actual = compile_inline('test @<b>{inline test} test2')
    assert_equal 'test <b>inline test</b> test2', actual
  end

  def test_inline_b_and_escape
    actual = compile_inline('test @<b>{inline<&;\\ test} test2')
    assert_equal 'test <b>inline&lt;&amp;;\\ test</b> test2', actual
  end

  def test_inline_tt
    actual = compile_inline('test @<tt>{inline test} test2')
    assert_equal %Q(test <code class="tt">inline test</code> test2), actual
  end

  def test_inline_tti
    actual = compile_inline('test @<tti>{inline test} test2')
    assert_equal %Q(test <code class="tt"><i>inline test</i></code> test2), actual
  end

  def test_inline_ttb
    actual = compile_inline('test @<ttb>{inline test} test2')
    assert_equal %Q(test <code class="tt"><b>inline test</b></code> test2), actual
  end

  def test_inline_hd_chap
    def @chapter.headline_index
      item = Book::Index::Item.new('chap1|test', [1, 1], 'te_st')
      idx = Book::HeadlineIndex.new(self)
      idx.add_item(item)
      idx
    end

    @config['secnolevel'] = 2
    actual = compile_inline('test @<hd>{chap1|test} test2')
    assert_equal 'test <a href="-.html#h1-1-1">「te_st」</a> test2', actual

    @config['secnolevel'] = 3
    actual = compile_inline('test @<hd>{chap1|test} test2')
    assert_equal 'test <a href="-.html#h1-1-1">「1.1.1 te_st」</a> test2', actual

    @config['chapterlink'] = nil
    @config['secnolevel'] = 2
    actual = compile_inline('test @<hd>{chap1|test} test2')
    assert_equal 'test 「te_st」 test2', actual

    @config['secnolevel'] = 3
    actual = compile_inline('test @<hd>{chap1|test} test2')
    assert_equal 'test 「1.1.1 te_st」 test2', actual
  end

  def test_inline_hd_chap_postdef_roman
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, 'locale.yml')
        File.open(file, 'w') { |f| f.write "locale: ja\nappendix: 付録%pR" }
        I18n.setup('ja')
        @chapter.instance_eval do
          def on_appendix?
            true
          end
        end

        def @chapter.headline_index
          item = Book::Index::Item.new('test', [1], 'te_st')
          idx = Book::HeadlineIndex.new(self)
          idx.add_item(item)
          idx
        end

        actual = compile_inline('test @<hd>{test} test2')
        assert_equal 'test <a href="-.html#hI-1">「I.1 te_st」</a> test2', actual

        @config['chapterlink'] = nil
        actual = compile_inline('test @<hd>{test} test2')
        assert_equal 'test 「I.1 te_st」 test2', actual
      end
    end
  end

  def test_inline_hd_chap_postdef_alpha
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, 'locale.yml')
        File.open(file, 'w') { |f| f.write "locale: ja\nappendix: 付録%pA" }
        I18n.setup('ja')
        @chapter.instance_eval do
          def on_appendix?
            true
          end
        end

        def @chapter.headline_index
          item = Book::Index::Item.new('test', [1], 'te_st')
          idx = Book::HeadlineIndex.new(self)
          idx.add_item(item)
          idx
        end

        actual = compile_inline('test @<hd>{test} test2')
        assert_equal 'test <a href="-.html#hA-1">「A.1 te_st」</a> test2', actual

        @config['chapterlink'] = nil
        actual = compile_inline('test @<hd>{test} test2')
        assert_equal 'test 「A.1 te_st」 test2', actual
      end
    end
  end

  def test_inline_uchar
    actual = compile_inline('test @<uchar>{2460} test2')
    assert_equal 'test &#x2460; test2', actual
  end

  def test_inline_balloon
    actual = compile_inline('test @<balloon>{①}')
    assert_equal %Q(test <span class="balloon">①</span>), actual
  end

  def test_inline_ruby
    actual = compile_inline('@<ruby>{粗雑,クルード}と思われているなら@<ruby>{繊細,テクニカル}にやり、繊細と思われているなら粗雑にやる。')
    assert_equal '<ruby>粗雑<rp>（</rp><rt>クルード</rt><rp>）</rp></ruby>と思われているなら<ruby>繊細<rp>（</rp><rt>テクニカル</rt><rp>）</rp></ruby>にやり、繊細と思われているなら粗雑にやる。', actual
  end

  def test_inline_ruby_comma
    actual = compile_inline('@<ruby>{foo\\, bar\\, buz,フー・バー・バズ}')
    assert_equal '<ruby>foo, bar, buz<rp>（</rp><rt>フー・バー・バズ</rt><rp>）</rp></ruby>', actual
  end

  def test_inline_ref
    actual = compile_inline('@<ref>{外部参照<>&}')
    assert_equal %Q(<a target='外部参照&lt;&gt;&amp;'>「●●　外部参照&lt;&gt;&amp;」</a>), actual
  end

  def test_inline_mathml
    begin
      require 'math_ml'
      require 'math_ml/symbol/character_reference'
    rescue LoadError
      return true
    end
    @config['mathml'] = true
    actual = compile_inline('@<m>{\\frac{-b \\pm \\sqrt{b^2 - 4ac\\}\\}{2a\\}}')
    @config['mathml'] = nil
    assert_equal %Q(<span class="equation"><math xmlns='http://www.w3.org/1998/Math/MathML' display='inline'><mfrac><mrow><mo stretchy='false'>-</mo><mi>b</mi><mo stretchy='false'>&#xb1;</mo><msqrt><mrow><msup><mi>b</mi><mn>2</mn></msup><mo stretchy='false'>-</mo><mn>4</mn><mi>a</mi><mi>c</mi></mrow></msqrt></mrow><mrow><mn>2</mn><mi>a</mi></mrow></mfrac></math></span>), actual
  end

  def test_inline_img
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1, 'sample photo')
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("@<img>{sampleimg}\n")
    expected = %Q(<p><span class="imgref"><a href="./-.html#sampleimg">図1.1</a></span></p>\n)
    assert_equal expected, actual

    @config['chapterlink'] = nil
    actual = compile_block("@<img>{sampleimg}\n")
    expected = %Q(<p><span class="imgref">図1.1</span></p>\n)
    assert_equal expected, actual
  end

  def test_inline_imgref
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1, 'sample photo')
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("@<imgref>{sampleimg}\n")
    expected = %Q(<p><span class="imgref"><a href="./-.html#sampleimg">図1.1</a></span>「sample photo」</p>\n)
    assert_equal expected, actual

    @config['chapterlink'] = nil
    actual = compile_block("@<imgref>{sampleimg}\n")
    expected = %Q(<p><span class="imgref">図1.1</span>「sample photo」</p>\n)
    assert_equal expected, actual
  end

  def test_inline_imgref2
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("@<imgref>{sampleimg}\n")
    expected = %Q(<p><span class="imgref"><a href="./-.html#sampleimg">図1.1</a></span></p>\n)
    assert_equal expected, actual

    @config['chapterlink'] = nil
    actual = compile_block("@<imgref>{sampleimg}\n")
    expected = %Q(<p><span class="imgref">図1.1</span></p>\n)
    assert_equal expected, actual
  end

  def test_inline_imgref3
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file1 = File.join(dir, 'images', 'img1.png')
        filet1 = File.join(dir, 'images', 'tbl1.png')
        file2 = File.join(dir, 'images', 'img2.png')
        file3 = File.join(dir, 'images', 'icon3.png')
        re1 = File.join(dir, 'sample1.re')
        cat = File.join(dir, 'catalog.yml')
        FileUtils.mkdir_p(File.join(dir, 'images'))
        File.open(file1, 'w') { |f| f.write '' }
        File.open(filet1, 'w') { |f| f.write '' }
        File.open(file2, 'w') { |f| f.write '' }
        File.open(file3, 'w') { |f| f.write '' }
        File.open(cat, 'w') { |f| f.write "CHAPS:\n  - sample1.re\n" }
        File.open(re1, 'w') { |f| f.write <<EOF }
= test

tbl1 is @<table>{tbl1}.

img2 is @<img>{img2}.

icon3 is @<icon>{icon3}.

//image[img1][image 1]{
//}

//imgtable[tbl1][table 1]{
//}

//image[img2][image 2]{
//}
EOF
        content = File.read(re1)
        actual = compile_block(content)

        expected = <<-EOS
<h1><a id="h1"></a><span class="secno">第1章　</span>test</h1>
<p>tbl1 is <span class="tableref"><a href="./-.html#tbl1">表1.1</a></span>.</p>
<p>img2 is <span class="imgref"><a href="./-.html#img2">図1.2</a></span>.</p>
<p>icon3 is <img src="images/icon3.png" alt="[icon3]" />.</p>
<div id="img1" class="image">
<img src="images/img1.png" alt="image 1" />
<p class="caption">
図1.1: image 1
</p>
</div>
<div id="tbl1" class="imgtable image">
<p class="caption">表1.1: table 1</p>
<img src="images/tbl1.png" alt="table 1" />
</div>
<div id="img2" class="image">
<img src="images/img2.png" alt="image 2" />
<p class="caption">
図1.2: image 2
</p>
</div>
EOS

        assert_equal expected, actual

        @config['chapterlink'] = nil
        actual = compile_block(content)

        expected = <<-EOS
<h1><a id="h1"></a><span class="secno">第1章　</span>test</h1>
<p>tbl1 is <span class="tableref">表1.1</span>.</p>
<p>img2 is <span class="imgref">図1.2</span>.</p>
<p>icon3 is <img src="images/icon3.png" alt="[icon3]" />.</p>
<div id="img1" class="image">
<img src="images/img1.png" alt="image 1" />
<p class="caption">
図1.1: image 1
</p>
</div>
<div id="tbl1" class="imgtable image">
<p class="caption">表1.1: table 1</p>
<img src="images/tbl1.png" alt="table 1" />
</div>
<div id="img2" class="image">
<img src="images/img2.png" alt="image 2" />
<p class="caption">
図1.2: image 2
</p>
</div>
EOS

        assert_equal expected, actual
      end
    end
  end

  def test_quote
    actual = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
<blockquote><p>foobar</p>
<p>buz</p></blockquote>
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//quote{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
<blockquote><p>foo bar</p>
<p>buz</p></blockquote>
EOS
    assert_equal expected, actual
  end

  def test_memo
    actual = compile_block("//memo[this is @<b>{test}<&>_]{\ntest1\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS
<div class="memo">
<p class="caption">this is <b>test</b>&lt;&amp;&gt;_</p>
<p>test1</p>
<p>test<i>2</i></p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_blankline
    actual = compile_block("//blankline\nfoo\n")
    expected = <<-EOS
<p><br /></p>
<p>foo</p>
EOS
    assert_equal expected, actual
  end

  def test_noindent
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    expected = <<-EOS
<p class="noindent">foobar</p>
<p>foo2bar2</p>
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//noindent\nfoo\nbar\n\nfoo2\nbar2\n")
    expected = <<-EOS
<p class="noindent">foo bar</p>
<p>foo2 bar2</p>
EOS
    assert_equal expected, actual
  end

  def test_flushright
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
<p class="flushright">foobar</p>
<p class="flushright">buz</p>
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//flushright{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
<p class="flushright">foo bar</p>
<p class="flushright">buz</p>
EOS
    assert_equal expected, actual
  end

  def test_centering
    actual = compile_block("//centering{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
<p class="center">foobar</p>
<p class="center">buz</p>
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//centering{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
<p class="center">foo bar</p>
<p class="center">buz</p>
EOS
    assert_equal expected, actual
  end

  def test_image
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo]{\n//}\n")
    expected = <<-EOS
<div id="sampleimg" class="image">
<img src="images/chap1-sampleimg.png" alt="sample photo" />
<p class="caption">
図1.1: sample photo
</p>
</div>
EOS
    assert_equal expected, actual

    @config['caption_position']['image'] = 'top'
    actual = compile_block("//image[sampleimg][sample photo]{\n//}\n")
    expected = <<-EOS
<div id="sampleimg" class="image">
<p class="caption">
図1.1: sample photo
</p>
<img src="images/chap1-sampleimg.png" alt="sample photo" />
</div>
EOS
    assert_equal expected, actual
  end

  def test_image_with_metric
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2]{\n//}\n")
    expected = <<-EOS
<div id="sampleimg" class="image">
<img src="images/chap1-sampleimg.png" alt="sample photo" class="width-120per" />
<p class="caption">
図1.1: sample photo
</p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_image_with_metric2
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//image[sampleimg][sample photo][scale=1.2,html::class=sample,latex::ignore=params]{\n//}\n")
    expected = <<-EOS
<div id="sampleimg" class="image">
<img src="images/chap1-sampleimg.png" alt="sample photo" class="width-120per sample" />
<p class="caption">
図1.1: sample photo
</p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_image_with_tricky_id
    def @chapter.image(_id)
      item = Book::Index::Item.new('123 あ_;', 1)
      item.instance_eval { @path = './images/chap1-123 あ_;.png' }
      item
    end

    actual = compile_block("//image[123 あ_;][sample photo]{\n//}\n")
    expected = <<-EOS
<div id="id_123-_E3_81_82___3B" class="image">
<img src="images/chap1-123 あ_;.png" alt="sample photo" />
<p class="caption">
図1.1: sample photo
</p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_indepimage
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo]\n")
    expected = <<-EOS
<div id="sampleimg" class="image">
<img src="images/chap1-sampleimg.png" alt="sample photo" />
<p class="caption">
図: sample photo
</p>
</div>
EOS
    assert_equal expected, actual

    @config['caption_position']['image'] = 'top'
    actual = compile_block("//indepimage[sampleimg][sample photo]\n")
    expected = <<-EOS
<div id="sampleimg" class="image">
<p class="caption">
図: sample photo
</p>
<img src="images/chap1-sampleimg.png" alt="sample photo" />
</div>
EOS
    assert_equal expected, actual
  end

  def test_indepimage_without_caption
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg]\n")
    expected = <<-EOS
<div id="sampleimg" class="image">
<img src="images/chap1-sampleimg.png" alt="" />
</div>
EOS
    assert_equal expected, actual
  end

  def test_indepimage_with_metric
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg][sample photo][scale=1.2]\n")
    expected = <<-EOS
<div id="sampleimg" class="image">
<img src="images/chap1-sampleimg.png" alt="sample photo" class="width-120per" />
<p class="caption">
図: sample photo
</p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_indepimage_with_metric2
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block(%Q(//indepimage[sampleimg][sample photo][scale=1.2, html::class="sample",latex::ignore=params]\n))
    expected = <<-EOS
<div id="sampleimg" class="image">
<img src="images/chap1-sampleimg.png" alt="sample photo" class="width-120per sample" />
<p class="caption">
図: sample photo
</p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_indepimage_without_caption_but_with_metric
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1)
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//indepimage[sampleimg][][scale=1.2]\n")
    expected = <<-EOS
<div id="sampleimg" class="image">
<img src="images/chap1-sampleimg.png" alt="" class="width-120per" />
</div>
EOS
    assert_equal expected, actual
  end

  def test_dlist
    actual = compile_block(" : foo\n  foo.\n  bar.\n")
    expected = <<-EOS
<dl>
<dt>foo</dt>
<dd>foo.bar.</dd>
</dl>
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block(" : foo\n  foo.\n  bar.\n")
    expected = <<-EOS
<dl>
<dt>foo</dt>
<dd>foo. bar.</dd>
</dl>
EOS
    assert_equal expected, actual
  end

  def test_dlist_with_bracket
    actual = compile_block(" : foo[bar]\n    foo.\n    bar.\n")
    expected = <<-EOS
<dl>
<dt>foo[bar]</dt>
<dd>foo.bar.</dd>
</dl>
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block(" : foo[bar]\n    foo.\n    bar.\n")
    expected = <<-EOS
<dl>
<dt>foo[bar]</dt>
<dd>foo. bar.</dd>
</dl>
EOS
    assert_equal expected, actual
  end

  def test_dlist_with_comment
    source = " : title\n  body\n\#@ comment\n\#@ comment\n : title2\n  body2\n"
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

  def test_dlist_beforeulol
    actual = compile_block(" : foo\n  foo.\n\npara\n\n : foo\n  foo.\n\n 1. bar\n\n : foo\n  foo.\n\n * bar\n")
    expected = <<-EOS
<dl>
<dt>foo</dt>
<dd>foo.</dd>
</dl>
<p>para</p>
<dl>
<dt>foo</dt>
<dd>foo.</dd>
</dl>
<ol>
<li>bar</li>
</ol>
<dl>
<dt>foo</dt>
<dd>foo.</dd>
</dl>
<ul>
<li>bar</li>
</ul>
EOS
    assert_equal expected, actual
  end

  def test_dt_inline
    actual = compile_block("//footnote[bar][bar]\n\n : foo@<fn>{bar}[]<>&@<m>$\\alpha[]$\n")

    expected = <<-EOS
<div class="footnote" epub:type="footnote" id="fn-bar"><p class="footnote">[*1] bar</p></div>
<dl>
<dt>foo<a id="fnb-bar" href="#fn-bar" class="noteref" epub:type="noteref">*1</a>[]&lt;&gt;&amp;<span class="equation">\\alpha[]</span></dt>
<dd></dd>
</dl>
EOS
    assert_equal expected, actual
  end

  def test_list
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS
<div id="samplelist" class="caption-code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<pre class="list">test1
test1.5

test<i>2</i>
</pre>
</div>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")
    expected = <<-EOS
<div id="samplelist" class="caption-code">
<pre class="list">test1
test1.5

test<i>2</i>
</pre>
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_inline_list
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    actual = compile_block("@<list>{samplelist}\n")
    assert_equal %Q(<p><span class="listref"><a href="./-.html#samplelist">リスト1.1</a></span></p>\n), actual

    @config['chapterlink'] = nil
    actual = compile_block("@<list>{samplelist}\n")
    assert_equal %Q(<p><span class="listref">リスト1.1</span></p>\n), actual
  end

  def test_inline_list_href
    book = ReVIEW::Book::Base.load
    book.config['chapterlink'] = true
    book.catalog = ReVIEW::Catalog.new('CHAPS' => %w[ch1.re ch2.re])
    io1 = StringIO.new("//list[sampletest][a]{\nfoo\n//}\n")
    io2 = StringIO.new("= BAR\n")
    chap1 = ReVIEW::Book::Chapter.new(book, 1, 'ch1', 'ch1.re', io1)
    chap2 = ReVIEW::Book::Chapter.new(book, 2, 'ch2', 'ch2.re', io2)
    book.parts = [ReVIEW::Book::Part.new(book, nil, [chap1, chap2])]
    builder = ReVIEW::HTMLBuilder.new
    comp = ReVIEW::Compiler.new(builder)
    builder.bind(comp, chap2, nil)

    chap1.generate_indexes
    actual = builder.inline_list('ch1|sampletest')
    assert_equal %Q(<span class="listref"><a href="./ch1.html#sampletest">リスト1.1</a></span>), actual
  end

  def test_list_pygments
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    begin
      require 'pygments'
    rescue LoadError
      $stderr.puts 'skip test_list_pygments_lang (cannot find pygments.rb)'
      return true
    end
    @book.config['highlight'] = {}
    @book.config['highlight']['html'] = 'pygments'
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")

    expected = <<-EOS
<div id="samplelist" class="caption-code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<pre class="list highlight">test1
test1.5

test&lt;i&gt;2&lt;/i&gt;
</pre>
</div>
    EOS
    assert_equal expected, actual
  end

  def test_list_pygments_lang
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    begin
      require 'pygments'
    rescue LoadError
      $stderr.puts 'skip test_list_pygments_lang (cannot find pygments.rb)'
      return true
    end
    @book.config['highlight'] = {}
    @book.config['highlight']['html'] = 'pygments'
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_][ruby]{\ndef foo(a1, a2=:test)\n  (1..3).times{|i| a.include?(:foo)}\n  return true\nend\n\n//}\n")

    expected = <<-EOS
<div id="samplelist" class="caption-code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<pre class="list language-ruby highlight"><span style="color: #008000; font-weight: bold">def</span> <span style="color: #0000FF">foo</span>(a1, a2<span style="color: #666666">=</span><span style="color: #19177C">:test</span>)
  (<span style="color: #666666">1..3</span>)<span style="color: #666666">.</span>times{<span style="color: #666666">\|</span>i<span style="color: #666666">|</span> a<span style="color: #666666">.</span>include?(<span style="color: #19177C">:foo</span>)}
  <span style="color: #008000; font-weight: bold">return</span> <span style="color: #008000">true</span>
<span style="color: #008000; font-weight: bold">end</span>
</pre>
</div>
EOS

    assert_equal expected, actual
  end

  def test_list_pygments_nulllang
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    begin
      require 'pygments'
    rescue LoadError
      $stderr.puts 'skip test_list_pygments_nulllang (cannot find pygments.rb)'
      return true
    end
    @book.config['highlight'] = {}
    @book.config['highlight']['html'] = 'pygments'
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_][]{\ndef foo(a1, a2=:test)\n  (1..3).times{|i| a.include?(:foo)}\n  return true\nend\n\n//}\n")

    expected = <<-EOS
<div id="samplelist" class="caption-code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<pre class="list highlight">def foo(a1, a2=:test)
  (1..3).times{|i| a.include?(:foo)}
  return true
end
</pre>
</div>
    EOS
    assert_equal expected, actual
  end

  def test_list_rouge
    begin
      require 'rouge'
    rescue LoadError
      $stderr.puts 'skip test_list_rouge (cannot find Rouge)'
      return true
    end
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    @book.config['highlight'] = {}
    @book.config['highlight']['html'] = 'rouge'
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_]{\ntest1\ntest1.5\n\ntest@<i>{2}\n//}\n")

    expected = <<-EOS
<div id="samplelist" class="caption-code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<pre class="list highlight">test1
test1.5

test&lt;i&gt;2&lt;/i&gt;
</pre>
</div>
EOS
    assert_equal expected, actual
  end

  def test_list_rouge_lang
    begin
      require 'rouge'
    rescue LoadError
      $stderr.puts 'skip test_list_rouge_lang (cannot find Rouge)'
      return true
    end
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    @book.config['highlight'] = {}
    @book.config['highlight']['html'] = 'rouge'
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_][ruby]{\ndef foo(a1, a2=:test)\n  (1..3).times{|i| a.include?(:foo)}\n  return true\nend\n\n//}\n")

    expected = <<-EOS
<div id="samplelist" class="caption-code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<pre class="list language-ruby highlight"><span class="k">def</span> <span class="nf">foo</span><span class="p">(</span><span class="n">a1</span><span class="p">,</span> <span class="n">a2</span><span class="o">=</span><span class="ss">:test</span><span class="p">)</span>
  <span class="p">(</span><span class="mi">1</span><span class="o">..</span><span class="mi">3</span><span class="p">).</span><span class="nf">times</span><span class="p">{</span><span class="o">|</span><span class="n">i</span><span class="o">|</span> <span class="n">a</span><span class="p">.</span><span class="nf">include?</span><span class="p">(</span><span class="ss">:foo</span><span class="p">)}</span>
  <span class="k">return</span> <span class="kp">true</span>
<span class="k">end</span>

</pre>
</div>
EOS
    assert_equal expected, actual
  end

  def test_list_rouge_nulllang
    begin
      require 'rouge'
    rescue LoadError
      $stderr.puts 'skip test_list_rouge_nulllang (cannot find Rouge)'
      return true
    end
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    @book.config['highlight'] = {}
    @book.config['highlight']['html'] = 'rouge'
    actual = compile_block("//list[samplelist][this is @<b>{test}<&>_][]{\ndef foo(a1, a2=:test)\n  (1..3).times{|i| a.include?(:foo)}\n  return true\nend\n\n//}\n")

    expected = <<-EOS
<div id="samplelist" class="caption-code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<pre class="list highlight">def foo(a1, a2=:test)
  (1..3).times{|i| a.include?(:foo)}
  return true
end

</pre>
</div>
EOS
    assert_equal expected, actual
  end

  def test_listnum
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end

    @book.config['highlight'] = false
    actual = compile_block(<<-EOS)
//listnum[samplelist][this is @<b>{test}<&>_][ruby]{
def foo(a1, a2=:test)
  (1..3).times{|i| a.include?(:foo)}
  return true
end
//}
EOS

    expected = <<-EOS
<div id="samplelist" class="code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<pre class="list language-ruby"> 1: def foo(a1, a2=:test)
 2:   (1..3).times{|i| a.include?(:foo)}
 3:   return true
 4: end
</pre>
</div>
EOS

    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block(<<-EOS)
//listnum[samplelist][this is @<b>{test}<&>_][ruby]{
def foo(a1, a2=:test)
  (1..3).times{|i| a.include?(:foo)}
  return true
end
//}
EOS

    expected = <<-EOS
<div id="samplelist" class="code">
<pre class="list language-ruby"> 1: def foo(a1, a2=:test)
 2:   (1..3).times{|i| a.include?(:foo)}
 3:   return true
 4: end
</pre>
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
</div>
EOS

    assert_equal expected, actual
  end

  def test_listnum_linenum
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end

    @book.config['highlight'] = false
    actual = compile_block(<<-EOS)
//firstlinenum[100]
//listnum[samplelist][this is @<b>{test}<&>_][ruby]{
def foo(a1, a2=:test)
  (1..3).times{|i| a.include?(:foo)}
  return true
end
//}
EOS

    expected = <<-EOS
<div id="samplelist" class="code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<pre class="list language-ruby">100: def foo(a1, a2=:test)
101:   (1..3).times{|i| a.include?(:foo)}
102:   return true
103: end
</pre>
</div>
EOS

    assert_equal expected, actual
  end

  def test_listnum_pygments_lang
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    begin
      require 'pygments'
    rescue LoadError
      $stderr.puts 'skip test_listnum_pygments_lang (cannot find pygments.rb)'
      return true
    end
    @book.config['highlight'] = {}
    @book.config['highlight']['html'] = 'pygments'
    actual = compile_block("//listnum[samplelist][this is @<b>{test}<&>_][ruby]{\ndef foo(a1, a2=:test)\n  (1..3).times{|i| a.include?(:foo)}\n  return true\nend\n\n//}\n")

    expected = <<-EOS
<div id="samplelist" class="code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<div class="highlight" style="background: #f8f8f8"><pre style="line-height: 125%"><span></span><span style="background-color: #f0f0f0; padding: 0 5px 0 5px">1 </span><span style="color: #008000; font-weight: bold">def</span> <span style="color: #0000FF">foo</span>(a1, a2<span style="color: #666666">=</span><span style="color: #19177C">:test</span>)
<span style="background-color: #f0f0f0; padding: 0 5px 0 5px">2 </span>  (<span style="color: #666666">1..3</span>)<span style="color: #666666">.</span>times{<span style="color: #666666">|</span>i<span style="color: #666666">|</span> a<span style="color: #666666">.</span>include?(<span style="color: #19177C">:foo</span>)}
<span style="background-color: #f0f0f0; padding: 0 5px 0 5px">3 </span>  <span style="color: #008000; font-weight: bold">return</span> <span style="color: #008000">true</span>
<span style="background-color: #f0f0f0; padding: 0 5px 0 5px">4 </span><span style="color: #008000; font-weight: bold">end</span>
</pre></div>
</div>
    EOS
    assert_equal expected, actual
  end

  def test_listnum_pygments_lang_linenum
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    begin
      require 'pygments'
    rescue LoadError
      $stderr.puts 'skip test_listnum_pygments_lang (cannot find pygments.rb)'
      return true
    end
    @book.config['highlight'] = {}
    @book.config['highlight']['html'] = 'pygments'
    actual = compile_block("//firstlinenum[100]\n//listnum[samplelist][this is @<b>{test}<&>_][ruby]{\ndef foo(a1, a2=:test)\n  (1..3).times{|i| a.include?(:foo)}\n  return true\nend\n\n//}\n")

    expected = <<-EOS
<div id="samplelist" class="code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<div class="highlight" style="background: #f8f8f8"><pre style="line-height: 125%"><span></span><span style="background-color: #f0f0f0; padding: 0 5px 0 5px">100 </span><span style="color: #008000; font-weight: bold">def</span> <span style="color: #0000FF">foo</span>(a1, a2<span style="color: #666666">=</span><span style="color: #19177C">:test</span>)
<span style="background-color: #f0f0f0; padding: 0 5px 0 5px">101 </span>  (<span style="color: #666666">1..3</span>)<span style="color: #666666">.</span>times{<span style="color: #666666">|</span>i<span style="color: #666666">|</span> a<span style="color: #666666">.</span>include?(<span style="color: #19177C">:foo</span>)}
<span style="background-color: #f0f0f0; padding: 0 5px 0 5px">102 </span>  <span style="color: #008000; font-weight: bold">return</span> <span style="color: #008000">true</span>
<span style="background-color: #f0f0f0; padding: 0 5px 0 5px">103 </span><span style="color: #008000; font-weight: bold">end</span>
</pre></div>
</div>
EOS

    assert_equal expected, actual
  end

  def test_listnum_pygments_lang_without_lang
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    begin
      require 'pygments'
    rescue LoadError
      $stderr.puts 'skip test_listnum_pygments_lang (cannot find pygments.rb)'
      return true
    end
    @book.config['highlight'] = {}
    @book.config['highlight']['html'] = 'pygments'
    @book.config['highlight']['lang'] = 'ruby'
    actual = compile_block("//listnum[samplelist][this is @<b>{test}<&>_]{\ndef foo(a1, a2=:test)\n  (1..3).times{|i| a.include?(:foo)}\n  return true\nend\n\n//}\n")

    expected = <<-EOS
<div id="samplelist" class="code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<div class="highlight" style="background: #f8f8f8"><pre style="line-height: 125%"><span></span><span style="background-color: #f0f0f0; padding: 0 5px 0 5px">1 </span><span style="color: #008000; font-weight: bold">def</span> <span style="color: #0000FF">foo</span>(a1, a2<span style="color: #666666">=</span><span style="color: #19177C">:test</span>)
<span style="background-color: #f0f0f0; padding: 0 5px 0 5px">2 </span>  (<span style="color: #666666">1..3</span>)<span style="color: #666666">.</span>times{<span style="color: #666666">|</span>i<span style="color: #666666">|</span> a<span style="color: #666666">.</span>include?(<span style="color: #19177C">:foo</span>)}
<span style="background-color: #f0f0f0; padding: 0 5px 0 5px">3 </span>  <span style="color: #008000; font-weight: bold">return</span> <span style="color: #008000">true</span>
<span style="background-color: #f0f0f0; padding: 0 5px 0 5px">4 </span><span style="color: #008000; font-weight: bold">end</span>
</pre></div>
</div>
    EOS
    assert_equal expected, actual
  end

  def test_listnum_rouge_lang
    begin
      require 'rouge'
    rescue LoadError
      $stderr.puts 'skip test_listnum_rouge_lang (cannot find Rouge)'
      return true
    end
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    @book.config['highlight'] = {}
    @book.config['highlight']['html'] = 'rouge'
    actual = compile_block("//listnum[samplelist][this is @<b>{test}<&>_][ruby]{\ndef foo(a1, a2=:test)\n  (1..3).times{|i| a.include?(:foo)}\n  return true\nend\n\n//}\n")

    expected = <<-EOS
<div id="samplelist" class="code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<table class="highlight rouge-table"><tbody><tr><td class="rouge-gutter gl"><pre class="lineno">1
2
3
4
5
</pre></td><td class="rouge-code"><pre><span class="k">def</span> <span class="nf">foo</span><span class="p">(</span><span class="n">a1</span><span class="p">,</span> <span class="n">a2</span><span class="o">=</span><span class="ss">:test</span><span class="p">)</span>
  <span class="p">(</span><span class="mi">1</span><span class="o">..</span><span class="mi">3</span><span class="p">).</span><span class="nf">times</span><span class="p">{</span><span class="o">|</span><span class="n">i</span><span class="o">|</span> <span class="n">a</span><span class="p">.</span><span class="nf">include?</span><span class="p">(</span><span class="ss">:foo</span><span class="p">)}</span>
  <span class="k">return</span> <span class="kp">true</span>
<span class="k">end</span>

</pre></td></tr></tbody></table>
</div>
    EOS

    assert_equal expected, actual
  end

  def test_listnum_rouge_lang_linenum
    begin
      require 'rouge'
    rescue LoadError
      $stderr.puts 'skip test_listnum_rouge_lang_linenum (cannot find Rouge)'
      return true
    end
    def @chapter.list(_id)
      Book::Index::Item.new('samplelist', 1)
    end
    @book.config['highlight'] = {}
    @book.config['highlight']['html'] = 'rouge'
    actual = compile_block("//firstlinenum[100]\n//listnum[samplelist][this is @<b>{test}<&>_][ruby]{\ndef foo(a1, a2=:test)\n  (1..3).times{|i| a.include?(:foo)}\n  return true\nend\n\n//}\n")

    expected = <<-EOB
<div id="samplelist" class="code">
<p class="caption">リスト1.1: this is <b>test</b>&lt;&amp;&gt;_</p>
<table class="highlight rouge-table"><tbody><tr><td class="rouge-gutter gl"><pre class="lineno">100
101
102
103
104
</pre></td><td class="rouge-code"><pre><span class="k">def</span> <span class="nf">foo</span><span class="p">(</span><span class="n">a1</span><span class="p">,</span> <span class="n">a2</span><span class="o">=</span><span class="ss">:test</span><span class="p">)</span>
  <span class="p">(</span><span class="mi">1</span><span class="o">..</span><span class="mi">3</span><span class="p">).</span><span class="nf">times</span><span class="p">{</span><span class="o">|</span><span class="n">i</span><span class="o">|</span> <span class="n">a</span><span class="p">.</span><span class="nf">include?</span><span class="p">(</span><span class="ss">:foo</span><span class="p">)}</span>
  <span class="k">return</span> <span class="kp">true</span>
<span class="k">end</span>

</pre></td></tr></tbody></table>
</div>
EOB

    assert_equal expected, actual
  end

  def test_source
    actual = compile_block("//source[foo/bar/test.rb]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
<div class="source-code">
<p class="caption">foo/bar/test.rb</p>
<pre class="source">foo
bar

buz
</pre>
</div>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//source[foo/bar/test.rb]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
<div class="source-code">
<pre class="source">foo
bar

buz
</pre>
<p class="caption">foo/bar/test.rb</p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_source_empty_caption
    actual = compile_block("//source[]{\nfoo\nbar\n\nbuz\n//}\n")
    expected = <<-EOS
<div class="source-code">
<pre class="source">foo
bar

buz
</pre>
</div>
EOS
    assert_equal expected, actual
  end

  def test_box
    actual = compile_block("//box{\nfoo\nbar\n//}\n")
    expected = <<-EOS
<div class="syntax">
<pre class="syntax">foo
bar
</pre>
</div>
EOS
    assert_equal expected, actual

    actual = compile_block("//box[FOO]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
<div class="syntax">
<p class="caption">FOO</p>
<pre class="syntax">foo
bar
</pre>
</div>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//box[FOO]{\nfoo\nbar\n//}\n")
    expected = <<-EOS
<div class="syntax">
<pre class="syntax">foo
bar
</pre>
<p class="caption">FOO</p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_emlist
    actual = compile_block("//emlist{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
<div class="emlist-code">
<pre class="emlist">lineA
lineB
</pre>
</div>
EOS
    assert_equal expected, actual
  end

  def test_emlist_pygments_lang
    begin
      require 'pygments'
    rescue LoadError
      $stderr.puts 'skip test_emlist_pygments_lang (cannot find pygments.rb)'
      return true
    end
    @book.config['highlight'] = {}
    @book.config['highlight']['html'] = 'pygments'
    actual = compile_block("//emlist[][sql]{\nSELECT COUNT(*) FROM tests WHERE tests.no > 10 AND test.name LIKE 'ABC%'\n//}\n")
    expected = <<-EOS
<div class="emlist-code">
<pre class="emlist language-sql highlight"><span style="color: #008000; font-weight: bold">SELECT</span> <span style="color: #008000; font-weight: bold">COUNT</span>(<span style="color: #666666">*</span>) <span style="color: #008000; font-weight: bold">FROM</span> tests <span style="color: #008000; font-weight: bold">WHERE</span> tests.<span style="color: #008000; font-weight: bold">no</span> <span style="color: #666666">&gt;</span> <span style="color: #666666">10</span> <span style="color: #008000; font-weight: bold">AND</span> test.name <span style="color: #008000; font-weight: bold">LIKE</span> <span style="color: #BA2121">&#39;ABC%&#39;</span>
</pre>
</div>
    EOS
    assert_equal expected, actual
  end

  def test_emlist_caption
    actual = compile_block("//emlist[cap1]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
<div class="emlist-code">
<p class="caption">cap1</p>
<pre class="emlist">lineA
lineB
</pre>
</div>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//emlist[cap1]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
<div class="emlist-code">
<pre class="emlist">lineA
lineB
</pre>
<p class="caption">cap1</p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_emlist_with_tab
    actual = compile_block("//emlist{\n\tlineA\n\t\tlineB\n\tlineC\n//}\n")
    expected = <<-EOS
<div class="emlist-code">
<pre class="emlist">        lineA
                lineB
        lineC
</pre>
</div>
EOS
    assert_equal expected, actual
  end

  def test_emlistnum
    @book.config['highlight'] = false
    actual = compile_block("//emlistnum{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
<div class="emlistnum-code">
<pre class="emlist"> 1: lineA
 2: lineB
</pre>
</div>
EOS
    assert_equal expected, actual
  end

  def test_emlistnum_lang
    @book.config['highlight'] = false
    actual = compile_block("//emlistnum[cap][text]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
<div class="emlistnum-code">
<p class="caption">cap</p>
<pre class="emlist language-text"> 1: lineA
 2: lineB
</pre>
</div>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//emlistnum[cap][text]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
<div class="emlistnum-code">
<pre class="emlist language-text"> 1: lineA
 2: lineB
</pre>
<p class="caption">cap</p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_emlistnum_lang_linenum
    @book.config['highlight'] = false
    actual = compile_block("//firstlinenum[1000]\n//emlistnum[cap][text]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
<div class="emlistnum-code">
<p class="caption">cap</p>
<pre class="emlist language-text">1000: lineA
1001: lineB
</pre>
</div>
EOS
    assert_equal expected, actual
  end

  def test_emlist_with_4tab
    @config['tabwidth'] = 4
    actual = compile_block("//emlist{\n\tlineA\n\t\tlineB\n\tlineC\n//}\n")
    expected = <<-EOS
<div class="emlist-code">
<pre class="emlist">    lineA
        lineB
    lineC
</pre>
</div>
EOS
    assert_equal expected, actual
  end

  def test_cmd
    actual = compile_block("//cmd{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
<div class="cmd-code">
<pre class="cmd">lineA
lineB
</pre>
</div>
EOS
    assert_equal expected, actual
  end

  def test_cmd_pygments
    begin
      require 'pygments'
    rescue LoadError
      return true
    end
    @book.config['highlight'] = {}
    @book.config['highlight']['html'] = 'pygments'
    actual = compile_block("//cmd{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
<div class="cmd-code">
<pre class="cmd"><span style="color: #888888">lineA</span>
<span style="color: #888888">lineB</span>
</pre>
</div>
EOS
    assert_equal expected, actual
  end

  def test_cmd_caption
    actual = compile_block("//cmd[cap1]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
<div class="cmd-code">
<p class="caption">cap1</p>
<pre class="cmd">lineA
lineB
</pre>
</div>
EOS
    assert_equal expected, actual

    @config['caption_position']['list'] = 'bottom'
    actual = compile_block("//cmd[cap1]{\nlineA\nlineB\n//}\n")
    expected = <<-EOS
<div class="cmd-code">
<pre class="cmd">lineA
lineB
</pre>
<p class="caption">cap1</p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_texequation
    return true if /mswin|mingw|cygwin/ =~ RUBY_PLATFORM
    return true unless system('latex -version 1>/dev/null 2>/dev/null')
    mktmpbookdir('catalog.yml' => "CHAPS:\n - ch01.re\n",
                 'ch01.re' => "= test\n\n//texequation{\np \\land \\bm{P} q\n//}\n") do |dir, book, _files|
      @book = book
      @book.config = @config
      @config['imgmath'] = true
      @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
      location = Location.new(nil, nil)
      @builder.bind(@compiler, @chapter, location)
      FileUtils.mkdir_p(File.join(dir, 'images'))
      expected = <<-EOB
<div class=\"equation\">
<img src=\"images/_review_math/_gen_XXX.png\" class=\"math_gen_84291054a12d278ea05694c20fbbc8e974ec66fc13be801c01dca764faeecccb\" alt="p \\land \\bm{P} q" />
</div>
      EOB
      tmpio = $stderr
      $stderr = StringIO.new
      begin
        result = compile_block("//texequation{\np \\land \\bm{P} q\n//}\n")
      ensure
        $stderr = tmpio
      end
      actual = result.gsub(/_gen_[0-9a-f]+\.png/, '_gen_XXX.png')
      assert_equal expected, actual
    end
  end

  def test_texequation_fail
    # Re:VIEW 3 never fail on defer mode. This test is only for Re:VIEW 2.
    return true if /mswin|mingw|cygwin/ =~ RUBY_PLATFORM
    return true unless system('latex -version 1>/dev/null 2>/dev/null')
    mktmpbookdir('catalog.yml' => "CHAPS:\n - ch01.re\n",
                 'ch01.re' => "= test\n\n//texequation{\np \\land \\bm{P}} q\n//}\n") do |dir, book, _files|
      @book = book
      @book.config = @config
      @config['review_version'] = 2
      @config['imgmath'] = true
      @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
      location = Location.new(nil, nil)
      @builder.bind(@compiler, @chapter, location)
      FileUtils.mkdir_p(File.join(dir, 'images'))
      tmpio = $stderr
      $stderr = StringIO.new
      begin
        assert_raise(ReVIEW::ApplicationError) do
          _result = compile_block("//texequation{\np \\land \\bm{P}} q\n//}\n")
        end
      ensure
        $stderr = tmpio
      end
    end
  end

  def test_bib
    def @chapter.bibpaper(_id)
      Book::Index::Item.new('samplebib', 1, 'sample bib')
    end

    assert_equal %Q(<a href="bib.html#bib-samplebib">[1]</a>), compile_inline('@<bib>{samplebib}')
  end

  def test_bib_noramlized
    def @chapter.bibpaper(_id)
      Book::Index::Item.new('sampleb=ib', 1, 'sample bib')
    end

    assert_equal %Q(<a href="bib.html#bib-id_sample_3Dbib">[1]</a>), compile_inline('@<bib>{sample=bib}')
  end

  def test_bib_htmlext
    def @chapter.bibpaper(_id)
      Book::Index::Item.new('samplebib', 1, 'sample bib')
    end

    @config['htmlext'] = 'xhtml'
    assert_equal %Q(<a href="bib.xhtml#bib-samplebib">[1]</a>), compile_inline('@<bib>{samplebib}')
  end

  def test_bibpaper
    def @chapter.bibpaper(_id)
      Book::Index::Item.new('samplebib', 1, 'sample bib')
    end

    actual = compile_block("//bibpaper[samplebib][sample bib @<b>{bold}]{\na\nb\n//}\n")
    expected = <<-EOS
<div class="bibpaper">
<a id="bib-samplebib">[1]</a> sample bib <b>bold</b>
<p>ab</p></div>
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//bibpaper[samplebib][sample bib @<b>{bold}]{\na\nb\n//}\n")
    expected = <<-EOS
<div class="bibpaper">
<a id="bib-samplebib">[1]</a> sample bib <b>bold</b>
<p>a b</p></div>
EOS
    assert_equal expected, actual
  end

  def test_bibpaper_normalized
    def @chapter.bibpaper(_id)
      Book::Index::Item.new('sample=bib', 1, 'sample bib')
    end

    actual = compile_block("//bibpaper[sample=bib][sample bib @<b>{bold}]{\na\nb\n//}\n")
    expected = <<-EOS
<div class="bibpaper">
<a id="bib-id_sample_3Dbib">[1]</a> sample bib <b>bold</b>
<p>ab</p></div>
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//bibpaper[sample=bib][sample bib @<b>{bold}]{\na\nb\n//}\n")
    expected = <<-EOS
<div class="bibpaper">
<a id="bib-id_sample_3Dbib">[1]</a> sample bib <b>bold</b>
<p>a b</p></div>
EOS
    assert_equal expected, actual
  end

  def test_bibpaper_with_anchor
    def @chapter.bibpaper(_id)
      Book::Index::Item.new('samplebib', 1, 'sample bib')
    end

    actual = compile_block("//bibpaper[samplebib][sample bib @<href>{http://example.jp}]{\na\nb\n//}\n")
    expected = <<-EOS
<div class="bibpaper">
<a id="bib-samplebib">[1]</a> sample bib <a href="http://example.jp" class="link">http://example.jp</a>
<p>ab</p></div>
EOS
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    actual = compile_block("//bibpaper[samplebib][sample bib @<href>{http://example.jp}]{\na\nb\n//}\n")
    expected = <<-EOS
<div class="bibpaper">
<a id="bib-samplebib">[1]</a> sample bib <a href="http://example.jp" class="link">http://example.jp</a>
<p>a b</p></div>
EOS
    assert_equal expected, actual
  end

  def column_helper(review)
    compile_block(review)
  end

  def test_column_1
    review = <<-EOS
===[column] prev column

inside prev column

===[column] test

inside column

===[/column]
EOS
    expected = <<-EOS
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
    review = <<-EOS
===[column] test

inside column

=== next level
EOS
    expected = <<-EOS
<div class="column">

<h3><a id="column-1"></a>test</h3>
<p>inside column</p>
</div>

<h3><a id="h1-0-1"></a>next level</h3>
EOS

    assert_equal expected, column_helper(review)
  end

  def test_column_3
    review = <<-EOS
===[column] test

inside column

===[/column_dummy]
EOS
    assert_raise(ReVIEW::ApplicationError) do
      column_helper(review)
    end
  end

  def test_column_ref
    review = <<-EOS
===[column]{foo} test

inside column

=== next level

this is @<column>{foo}.
EOS
    expected = <<-EOS
<div class="column">

<h3 id="foo"><a id="column-1"></a>test</h3>
<p>inside column</p>
</div>

<h3><a id="h1-0-1"></a>next level</h3>
<p>this is <a href="-.html#column-1" class="columnref">コラム「test」</a>.</p>
EOS

    assert_equal expected, column_helper(review)

    @config['chapterlink'] = nil
    expected = <<-EOS
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
      item = Book::Index::Item.new('chap1|column', 1, 'column_cap')
      idx = Book::ColumnIndex.new
      idx.add_item(item)
      idx
    end

    actual = compile_inline('test @<column>{chap1|column} test2')
    expected = 'test <a href="-.html#column-1" class="columnref">コラム「column_cap」</a> test2'
    assert_equal expected, actual

    @config['chapterlink'] = nil
    actual = compile_inline('test @<column>{chap1|column} test2')
    expected = 'test コラム「column_cap」 test2'
    assert_equal expected, actual
  end

  def test_ul
    src = <<-EOS
  * AAA
  * BBB
EOS
    expected = <<-EOS
<ul>
<li>AAA</li>
<li>BBB</li>
</ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_cont
    src = <<-EOS
  * AAA
    -AA
  * BBB
    -BB
EOS
    expected = <<-EOS
<ul>
<li>AAA-AA</li>
<li>BBB-BB</li>
</ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual

    @book.config['join_lines_by_lang'] = true
    expected = <<-EOS
<ul>
<li>AAA -AA</li>
<li>BBB -BB</li>
</ul>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_ul_nest1
    src = <<-EOS
  * AAA
  ** AA
EOS

    expected = <<-EOS
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
    src = <<-EOS
  * AAA
  ** AA
  * BBB
  ** BB
EOS

    expected = <<-EOS
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
    src = <<-EOS
  ** AAA
  * AA
EOS

    e = assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
    assert_equal ':1: error: too many *.', e.message
  end

  def test_ul_nest4
    src = <<-EOS
  * A
  ** AA
  *** AAA
  * B
  ** BB
EOS

    expected = <<-EOS
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

  def test_ol
    src = <<-EOS
  3. AAA
  3. BBB
EOS

    expected = <<-EOS
<ol>
<li>AAA</li>
<li>BBB</li>
</ol>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_inline_raw0
    assert_equal 'normal', compile_inline('@<raw>{normal}')
  end

  def test_inline_raw1
    assert_equal 'body', compile_inline('@<raw>{|html|body}')
  end

  def test_inline_raw2
    assert_equal 'body', compile_inline('@<raw>{|html, latex|body}')
  end

  def test_inline_raw3
    assert_equal '', compile_inline('@<raw>{|idgxml, latex|body}')
  end

  def test_inline_raw4
    assert_equal '|html body', compile_inline('@<raw>{|html body}')
  end

  def test_inline_raw5
    assert_equal "nor\nmal", compile_inline('@<raw>{|html|nor\\nmal}')
  end

  def test_inline_embed0
    assert_equal 'normal', compile_inline('@<embed>{normal}')
  end

  def test_inline_embed1
    assert_equal 'body', compile_inline('@<embed>{|html|body}')
  end

  def test_inline_embed3
    assert_equal '', compile_inline('@<embed>{|idgxml, latex|body}')
  end

  def test_inline_embed5
    assert_equal 'nor\\nmal', compile_inline('@<embed>{|html|nor\\nmal}')
  end

  def test_inline_embed_math1
    assert_equal '\[ \frac{\partial f}{\partial x} =x^2+xy \]', compile_inline('@<embed>{\[ \frac{\partial f\}{\partial x\} =x^2+xy \]}')
  end

  def test_inline_embed_math1a
    assert_equal '\[ \frac{\partial f}{\partial x} =x^2+xy \]', compile_inline('@<embed>{\\[ \\frac{\\partial f\}{\\partial x\} =x^2+xy \\]}')
  end

  def test_inline_embed_math1b
    assert_equal '\[ \frac{\partial f}{\partial x} =x^2+xy \]', compile_inline('@<embed>{\\\\[ \\\\frac{\\\\partial f\}{\\\\partial x\} =x^2+xy \\\\]}')
  end

  def test_inline_embed_math1c
    assert_equal '\\[ \\frac{}{} \\]',
                 compile_inline('@<embed>{\[ \\frac{\}{\} \\]}')
  end

  def test_inline_embed_n1
    assert_equal '\\n', compile_inline('@<embed>{\\n}')
  end

  def test_inline_embed_n2
    assert_equal '\\n', compile_inline('@<embed>{\\\\n}')
  end

  def test_inline_embed_brace_right0
    assert_equal '}', compile_inline('@<embed>{\\}}')
  end

  def test_inline_embed_brace_right1
    assert_equal '\\}', compile_inline('@<embed>{\\\\}}')
  end

  def test_inline_embed_brace_right2
    assert_equal '\\}', compile_inline('@<embed>{\\\\\\}}')
  end

  def test_inline_embed_brace_right3
    assert_equal '\\\\}', compile_inline('@<embed>{\\\\\\\\}}')
  end

  def test_block_raw0
    actual = compile_block(%Q(//raw[<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected, actual
  end

  def test_block_raw1
    actual = compile_block(%Q(//raw[|html|<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected, actual
  end

  def test_block_raw2
    actual = compile_block(%Q(//raw[|html, latex|<>!"\\n& ]\n))
    expected = %Q(<>!"\n& )
    assert_equal expected, actual
  end

  def test_block_raw3
    actual = compile_block(%Q(//raw[|latex, idgxml|<>!"\\n& ]\n))
    expected = ''
    assert_equal expected, actual
  end

  def test_block_raw4
    actual = compile_block(%Q(//raw[|html <>!"\\n& ]\n))
    expected = %Q(|html <>!"\n& )
    assert_equal expected, actual
  end

  def test_embed0
    lines = '//embed{' + "\n" +
            %Q( <>!"\\\\n& ) + "\n" +
            '//}' + "\n"
    actual = compile_block(lines)
    expected = %Q( <>!"\\\\n& ) + "\n"
    assert_equal expected, actual
  end

  def test_embed1
    actual = compile_block("//embed[|html|]{\n" +
                           %Q(<>!"\\\\n& \n) +
                           "//}\n")
    expected = %Q(<>!"\\\\n& \n)
    assert_equal expected, actual
  end

  def test_embed2
    actual = compile_block("//embed[html, latex]{\n" +
                           %Q(<>!"\\\\n& \n) +
                           "//}\n")
    expected = %Q(<>!"\\\\n& \n)
    assert_equal expected, actual
  end

  def test_embed2a
    actual = compile_block("//embed[|html, latex|]{\n" +
                           %Q(<>!"\\\\n& \n) +
                           "//}\n")
    expected = %Q(<>!"\\\\n& \n)
    assert_equal expected, actual
  end

  def test_embed2b
    actual = compile_block("//embed[html, latex]{\n" +
                           '#@# comments are not ignored in //embed block' + "\n" +
                           %Q(<>!"\\\\n& \n) +
                           "//}\n")
    expected = '#@# comments are not ignored in //embed block' + "\n" + %Q(<>!"\\\\n& \n)
    assert_equal expected, actual
  end

  def test_footnote
    actual = compile_block("//footnote[foo][bar\\a\\$buz]\n")
    expected = <<-'EOS'
<div class="footnote" epub:type="footnote" id="fn-foo"><p class="footnote">[*1] bar\a\$buz</p></div>
EOS
    assert_equal expected, actual

    @book.config['epubmaker'] ||= {}
    @book.config['epubmaker']['back_footnote'] = true
    actual = compile_block("//footnote[foo][bar\\a\\$buz]\n")
    expected = <<-'EOS'
<div class="footnote" epub:type="footnote" id="fn-foo"><p class="footnote"><a href="#fnb-foo">⏎</a>[*1] bar\a\$buz</p></div>
EOS
    assert_equal expected, actual

    I18n.set('html_footnote_textmark', '+%s:')
    I18n.set('html_footnote_backmark', '←')
    actual = compile_block("//footnote[foo][bar\\a\\$buz]\n")
    expected = <<-'EOS'
<div class="footnote" epub:type="footnote" id="fn-foo"><p class="footnote"><a href="#fnb-foo">←</a>+1:bar\a\$buz</p></div>
EOS
    assert_equal expected, actual
  end

  def test_footnote_with_tricky_id
    actual = compile_block("//footnote[123 あ_;][bar\\a\\$buz]\n")
    expected = <<-'EOS'
<div class="footnote" epub:type="footnote" id="fn-id_123-_E3_81_82___3B"><p class="footnote">[*1] bar\a\$buz</p></div>
EOS
    assert_equal expected, actual
  end

  def test_inline_fn
    fn = compile_block("//footnote[foo][bar]\n\n@<fn>{foo}\n")
    expected = <<-EOS
<div class=\"footnote\" epub:type=\"footnote\" id=\"fn-foo\"><p class=\"footnote\">[*1] bar</p></div>
<p><a id="fnb-foo" href="#fn-foo" class="noteref" epub:type="noteref">*1</a></p>
EOS
    assert_equal expected, fn
    I18n.set('html_footnote_refmark', '+%s')
    fn = compile_block("//footnote[foo][bar]\n\n@<fn>{foo}\n")
    expected = <<-EOS
<div class=\"footnote\" epub:type=\"footnote\" id=\"fn-foo\"><p class=\"footnote\">[*1] bar</p></div>
<p><a id="fnb-foo" href="#fn-foo" class="noteref" epub:type="noteref">+1</a></p>
EOS
    assert_equal expected, fn
  end

  def test_inline_hd
    book = ReVIEW::Book::Base.load
    book.catalog = ReVIEW::Catalog.new('CHAPS' => %w[ch1.re ch2.re])
    io1 = StringIO.new("= test1\n\nfoo\n\n== test1-1\n\nbar\n\n== test1-2\n\nbar\n\n")
    io2 = StringIO.new("= test2\n\nfoo\n\n== test2-1\n\nbar\n\n== test2-2\n\nbar\n\n")
    chap1 = ReVIEW::Book::Chapter.new(book, 1, 'ch1', 'ch1.re', io1)
    chap2 = ReVIEW::Book::Chapter.new(book, 2, 'ch2', 'ch2.re', io2)
    book.parts = [ReVIEW::Book::Part.new(book, nil, [chap1, chap2])]
    builder = ReVIEW::HTMLBuilder.new
    comp = ReVIEW::Compiler.new(builder)
    builder.bind(comp, chap2, nil)

    chap1.generate_indexes
    chap2.generate_indexes
    hd = builder.inline_hd('ch1|test1-1')
    assert_equal '<a href="ch1.html#h1-1">「1.1 test1-1」</a>', hd

    builder.instance_eval { @book.config['chapterlink'] = nil }
    hd = builder.inline_hd('ch1|test1-1')
    assert_equal '「1.1 test1-1」', hd
  end

  def test_inline_hd_for_part
    book = ReVIEW::Book::Base.load
    book.catalog = ReVIEW::Catalog.new('CHAPS' => %w[ch1.re ch2.re])
    io1 = StringIO.new("= test1\n\nfoo\n\n== test1-1\n\nbar\n\n== test1-2\n\nbar\n\n")
    io2 = StringIO.new("= test2\n\nfoo\n\n== test2-1\n\nbar\n\n== test2-2\n\nbar\n\n")
    io_p1 = StringIO.new("= part1\n\nfoo\n\n== part1-1\n\nbar\n\n== part1-2\n\nbar\n\n")
    chap1 = ReVIEW::Book::Chapter.new(book, 1, 'ch1', 'ch1.re', io1)
    chap2 = ReVIEW::Book::Chapter.new(book, 2, 'ch2', 'ch2.re', io2)
    book.parts = [ReVIEW::Book::Part.new(book, 1, [chap1, chap2], 'part1.re', io_p1)]
    builder = ReVIEW::HTMLBuilder.new
    comp = ReVIEW::Compiler.new(builder)
    builder.bind(comp, chap2, nil)
    book.generate_indexes

    hd = builder.inline_hd('part1|part1-1')
    assert_equal '<a href="part1.html#h1-1">「1.1 part1-1」</a>', hd

    builder.instance_eval { @book.config['chapterlink'] = nil }
    hd = builder.inline_hd('part1|part1-1')
    assert_equal '「1.1 part1-1」', hd
  end

  def test_inline_hd_with_block
    io1 = StringIO.new("= test1\n=={foo} foo\n//emlist{\n======\nbar\n======\n}\n//}\n=={bar} bar")
    chap1 = Book::Chapter.new(@book, 1, '-', nil, io1)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, chap1, location)
    hd = @builder.inline_hd('foo')
    assert_equal '<a href="-.html#h1-1">「1.1 foo」</a>', hd

    @config['chapterlink'] = nil
    hd = @builder.inline_hd('foo')
    assert_equal '「1.1 foo」', hd

    hd = @builder.inline_hd('bar')
    assert_equal '「1.2 bar」', hd
  end

  def test_table
    actual = compile_block("//table{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
<div class="table">
<table>
<tr><th>aaa</th><th>bbb</th></tr>
<tr><td>ccc</td><td>ddd&lt;&gt;&amp;</td></tr>
</table>
</div>
EOS
    assert_equal expected, actual

    actual = compile_block("//table[foo][FOO]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
<div id="foo" class="table">
<p class="caption">表1.1: FOO</p>
<table>
<tr><th>aaa</th><th>bbb</th></tr>
<tr><td>ccc</td><td>ddd&lt;&gt;&amp;</td></tr>
</table>
</div>
EOS
    assert_equal expected, actual

    @config['caption_position']['table'] = 'bottom'
    actual = compile_block("//table[foo][FOO]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
<div id="foo" class="table">
<table>
<tr><th>aaa</th><th>bbb</th></tr>
<tr><td>ccc</td><td>ddd&lt;&gt;&amp;</td></tr>
</table>
<p class="caption">表1.1: FOO</p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_empty_table
    e = assert_raises(ReVIEW::ApplicationError) { compile_block "//table{\n//}\n" }
    assert_equal ':2: error: no rows in the table', e.message

    e = assert_raises(ReVIEW::ApplicationError) { compile_block "//table{\n------------\n//}\n" }
    assert_equal ':3: error: no rows in the table', e.message
  end

  def test_inline_table
    def @chapter.table(_id)
      Book::Index::Item.new('sampletable', 1)
    end
    actual = compile_block("@<table>{sampletest}\n")
    assert_equal %Q(<p><span class="tableref"><a href="./-.html#sampletest">表1.1</a></span></p>\n), actual

    @config['chapterlink'] = nil
    actual = compile_block("@<table>{sampletest}\n")
    assert_equal %Q(<p><span class="tableref">表1.1</span></p>\n), actual
  end

  def test_emtable
    actual = compile_block("//emtable[foo]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n//emtable{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
<div class="table">
<p class="caption">foo</p>
<table>
<tr><th>aaa</th><th>bbb</th></tr>
<tr><td>ccc</td><td>ddd&lt;&gt;&amp;</td></tr>
</table>
</div>
<div class="table">
<table>
<tr><th>aaa</th><th>bbb</th></tr>
<tr><td>ccc</td><td>ddd&lt;&gt;&amp;</td></tr>
</table>
</div>
EOS
    assert_equal expected, actual

    @config['caption_position']['table'] = 'bottom'
    actual = compile_block("//emtable[foo]{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n//emtable{\naaa\tbbb\n------------\nccc\tddd<>&\n//}\n")
    expected = <<-EOS
<div class="table">
<table>
<tr><th>aaa</th><th>bbb</th></tr>
<tr><td>ccc</td><td>ddd&lt;&gt;&amp;</td></tr>
</table>
<p class="caption">foo</p>
</div>
<div class="table">
<table>
<tr><th>aaa</th><th>bbb</th></tr>
<tr><td>ccc</td><td>ddd&lt;&gt;&amp;</td></tr>
</table>
</div>
EOS
    assert_equal expected, actual
  end

  def test_imgtable
    def @chapter.image(_id)
      item = Book::Index::Item.new('sampleimg', 1, 'sample img')
      item.instance_eval { @path = './images/chap1-sampleimg.png' }
      item
    end

    actual = compile_block("//imgtable[sampleimg][test for imgtable]{\n//}\n")
    expected = <<-EOS
<div id="sampleimg" class="imgtable image">
<p class="caption">表1.1: test for imgtable</p>
<img src="images/chap1-sampleimg.png" alt="test for imgtable" />
</div>
EOS
    assert_equal expected, actual

    @config['caption_position']['table'] = 'bottom'
    actual = compile_block("//imgtable[sampleimg][test for imgtable]{\n//}\n")
    expected = <<-EOS
<div id="sampleimg" class="imgtable image">
<img src="images/chap1-sampleimg.png" alt="test for imgtable" />
<p class="caption">表1.1: test for imgtable</p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_table_row_separator
    src = "//table{\n1\t2\t\t3  4| 5\n------------\na b\tc  d   |e\n//}\n"
    expected = <<-EOS
<div class="table">
<table>
<tr><th>1</th><th>2</th><th>3  4| 5</th></tr>
<tr><td>a b</td><td>c  d   |e</td><td></td></tr>
</table>
</div>
EOS
    actual = compile_block(src)
    assert_equal expected, actual

    @config['table_row_separator'] = 'singletab'
    actual = compile_block(src)
    expected = <<-EOS
<div class="table">
<table>
<tr><th>1</th><th>2</th><th></th><th>3  4| 5</th></tr>
<tr><td>a b</td><td>c  d   |e</td><td></td><td></td></tr>
</table>
</div>
EOS
    assert_equal expected, actual

    @config['table_row_separator'] = 'spaces'
    actual = compile_block(src)
    expected = <<-EOS
<div class="table">
<table>
<tr><th>1</th><th>2</th><th>3</th><th>4|</th><th>5</th></tr>
<tr><td>a</td><td>b</td><td>c</td><td>d</td><td>|e</td></tr>
</table>
</div>
EOS
    assert_equal expected, actual

    @config['table_row_separator'] = 'verticalbar'
    actual = compile_block(src)
    expected = <<-EOS
<div class="table">
<table>
<tr><th>1	2		3  4</th><th>5</th></tr>
<tr><td>a b	c  d</td><td>e</td></tr>
</table>
</div>
EOS
    assert_equal expected, actual
  end

  def test_major_blocks
    actual = compile_block("//note{\nA\n\nB\n//}\n//note[caption]{\nA\n//}")
    expected = <<-EOS
<div class="note">
<p>A</p>
<p>B</p>
</div>
<div class="note">
<p class="caption">caption</p>
<p>A</p>
</div>
EOS
    assert_equal expected, actual

    actual = compile_block("//memo{\nA\n\nB\n//}\n//memo[caption]{\nA\n//}")
    expected = <<-EOS
<div class="memo">
<p>A</p>
<p>B</p>
</div>
<div class="memo">
<p class="caption">caption</p>
<p>A</p>
</div>
EOS
    assert_equal expected, actual

    actual = compile_block("//info{\nA\n\nB\n//}\n//info[caption]{\nA\n//}")
    expected = <<-EOS
<div class="info">
<p>A</p>
<p>B</p>
</div>
<div class="info">
<p class="caption">caption</p>
<p>A</p>
</div>
EOS
    assert_equal expected, actual

    actual = compile_block("//important{\nA\n\nB\n//}\n//important[caption]{\nA\n//}")
    expected = <<-EOS
<div class="important">
<p>A</p>
<p>B</p>
</div>
<div class="important">
<p class="caption">caption</p>
<p>A</p>
</div>
EOS
    assert_equal expected, actual

    actual = compile_block("//caution{\nA\n\nB\n//}\n//caution[caption]{\nA\n//}")
    expected = <<-EOS
<div class="caution">
<p>A</p>
<p>B</p>
</div>
<div class="caution">
<p class="caption">caption</p>
<p>A</p>
</div>
EOS
    assert_equal expected, actual

    actual = compile_block("//notice{\nA\n\nB\n//}\n//notice[caption]{\nA\n//}")
    expected = <<-EOS
<div class="notice">
<p>A</p>
<p>B</p>
</div>
<div class="notice">
<p class="caption">caption</p>
<p>A</p>
</div>
EOS
    assert_equal expected, actual

    actual = compile_block("//warning{\nA\n\nB\n//}\n//warning[caption]{\nA\n//}")
    expected = <<-EOS
<div class="warning">
<p>A</p>
<p>B</p>
</div>
<div class="warning">
<p class="caption">caption</p>
<p>A</p>
</div>
EOS
    assert_equal expected, actual

    actual = compile_block("//tip{\nA\n\nB\n//}\n//tip[caption]{\nA\n//}")
    expected = <<-EOS
<div class="tip">
<p>A</p>
<p>B</p>
</div>
<div class="tip">
<p class="caption">caption</p>
<p>A</p>
</div>
EOS
    assert_equal expected, actual
  end

  def test_minicolumn_blocks
    %w[note memo tip info warning important caution notice].each do |type|
      src = <<-EOS
//#{type}[#{type}1]{

//}

//#{type}[#{type}2]{
//}
EOS

      expected = <<-EOS
<div class="#{type}">
<p class="caption">#{type}1</p>
</div>
<div class="#{type}">
<p class="caption">#{type}2</p>
</div>
EOS
      assert_equal expected, compile_block(src)

      src = <<-EOS
//#{type}[#{type}2]{

//}

//#{type}[#{type}3]{

//}

//#{type}[#{type}4]{

//}

//#{type}[#{type}5]{

//}

//#{type}[#{type}6]{

//}
EOS

      expected = <<-EOS
<div class="#{type}">
<p class="caption">#{type}2</p>
</div>
<div class="#{type}">
<p class="caption">#{type}3</p>
</div>
<div class="#{type}">
<p class="caption">#{type}4</p>
</div>
<div class="#{type}">
<p class="caption">#{type}5</p>
</div>
<div class="#{type}">
<p class="caption">#{type}6</p>
</div>
EOS
      assert_equal expected, compile_block(src)

      src = <<-EOS
//#{type}{

 * A

 1. B

//}

//#{type}[OMITEND1]{

//emlist{
LIST
//}

//}

//#{type}[OMITEND2]{
//}
EOS

      expected = <<-EOS
<div class="#{type}">
<ul>
<li>A</li>
</ul>
<ol>
<li>B</li>
</ol>
</div>
<div class="#{type}">
<p class="caption">OMITEND1</p>
<div class="emlist-code">
<pre class="emlist">LIST
</pre>
</div>
</div>
<div class="#{type}">
<p class="caption">OMITEND2</p>
</div>
EOS
      assert_equal expected, compile_block(src)
    end
  end

  def test_minicolumn_blocks_nest_error1
    %w[note memo tip info warning important caution notice].each do |type|
      @builder.doc_status.clear
      src = <<-EOS
//#{type}{

//#{type}{
//}

//}
EOS
      e = assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
      assert_match(/minicolumn cannot be nested:/, e.message)
    end
  end

  def test_minicolumn_blocks_nest_error2
    %w[note memo tip info warning important caution notice].each do |type|
      @builder.doc_status.clear
      src = <<-EOS
//#{type}{

//#{type}{

//}

//}
EOS
      e = assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
      assert_match(/minicolumn cannot be nested:/, e.message)
    end
  end

  def test_minicolumn_blocks_nest_error3
    %w[memo tip info warning important caution notice].each do |type|
      @builder.doc_status.clear
      src = <<-EOS
//#{type}{

//note{

//}

//}
EOS
      e = assert_raises(ReVIEW::ApplicationError) { compile_block(src) }
      assert_match(/minicolumn cannot be nested:/, e.message)
    end
  end

  def test_comment
    actual = compile_block('//comment[コメント]')
    assert_equal '', actual
  end

  def test_comment_for_draft
    @config['draft'] = true
    actual = compile_block('//comment[コメント<]')
    assert_equal %Q(<div class="draft-comment">コメント&lt;</div>\n), actual
    actual = compile_block("//comment{\nA<>\nB&\n//}")
    assert_equal %Q(<div class="draft-comment">A&lt;&gt;<br />B&amp;</div>\n), actual
  end

  def test_inline_comment
    actual = compile_inline('test @<comment>{コメント} test2')
    assert_equal 'test  test2', actual
  end

  def test_inline_comment_for_draft
    @config['draft'] = true
    actual = compile_inline('test @<comment>{コメント} test2')
    assert_equal %Q(test <span class="draft-comment">コメント</span> test2), actual
  end

  def test_inline_fence
    actual = compile_inline('test @<code>|@<code>{$サンプル$}|')
    assert_equal 'test <code class="inline-code tt">@&lt;code&gt;{$サンプル$}</code>', actual
  end

  def test_inline_w
    Dir.mktmpdir do |dir|
      File.open(File.join(dir, 'words.csv'), 'w') do |f|
        f.write <<EOB
"F","foo"
"B","bar""\\<>_@<b>{BAZ}"
EOB
      end
      @book.config['words_file'] = File.join(dir, 'words.csv')
      io = StringIO.new
      @builder.instance_eval{ @logger = ReVIEW::Logger.new(io) }
      actual = compile_block('@<w>{F} @<w>{B} @<wb>{B} @<w>{N}')
      assert_equal %Q(<p>foo bar&quot;\\&lt;&gt;_@&lt;b&gt;{BAZ} <b>bar&quot;\\&lt;&gt;_@&lt;b&gt;{BAZ}</b> [missing word: N]</p>\n), actual
      assert_match(/WARN --: :1: word not bound: N/, io.string)
    end
  end

  def test_inline_unknown
    e = assert_raises(ReVIEW::ApplicationError) { compile_block "@<img>{n}\n" }
    assert_equal ':1: error: unknown image: n', e.message
    e = assert_raises(ReVIEW::ApplicationError) { compile_block "@<fn>{n}\n" }
    assert_equal ':1: error: unknown footnote: n', e.message
    e = assert_raises(ReVIEW::ApplicationError) { compile_block "@<hd>{n}\n" }
    assert_equal ':1: error: unknown headline: n', e.message
    %w[list table column].each do |name|
      e = assert_raises(ReVIEW::ApplicationError) { compile_block "@<#{name}>{n}\n" }
      assert_equal ":1: error: unknown #{name}: n", e.message
    end
    %w[chap chapref title].each do |name|
      e = assert_raises(ReVIEW::ApplicationError) { compile_block "@<#{name}>{n}\n" }
      assert_equal ':1: error: key not found: "n"', e.message
    end
  end

  def test_texequation_plain
    src = <<-EOS
//texequation{
e=mc^2
//}
EOS
    expected = <<-EOS
<div class="equation">
<pre>e=mc^2
</pre>
</div>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end

  def test_texequation_with_caption
    src = <<-EOS
@<eq>{emc2}

//texequation[emc2][The Equivalence of Mass @<i>{and} Energy]{
e=mc^2
//}
EOS
    expected = <<-EOS
<p><span class="eqref"><a href="./-.html#emc2">式1.1</a></span></p>
<div id="emc2" class="caption-equation">
<p class="caption">式1.1: The Equivalence of Mass <i>and</i> Energy</p>
<div class="equation">
<pre>e=mc^2
</pre>
</div>
</div>
EOS
    actual = compile_block(src)
    assert_equal expected, actual

    @config['chapterlink'] = nil
    expected = <<-EOS
<p><span class="eqref">式1.1</span></p>
<div id="emc2" class="caption-equation">
<p class="caption">式1.1: The Equivalence of Mass <i>and</i> Energy</p>
<div class="equation">
<pre>e=mc^2
</pre>
</div>
</div>
EOS
    actual = compile_block(src)
    assert_equal expected, actual

    @config['caption_position']['equation'] = 'bottom'
    expected = <<-EOS
<p><span class="eqref">式1.1</span></p>
<div id="emc2" class="caption-equation">
<div class="equation">
<pre>e=mc^2
</pre>
</div>
<p class="caption">式1.1: The Equivalence of Mass <i>and</i> Energy</p>
</div>
EOS
    actual = compile_block(src)
    assert_equal expected, actual
  end
end
