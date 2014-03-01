# encoding: utf-8

require 'test_helper'
require 'review'
require 'review/compiler'
require 'review/book'
require 'review/topbuilder'
require 'review/i18n'

class TOPBuidlerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @builder = TOPBuilder.new()
    @param = {
      "secnolevel" => 2,
      "inencoding" => "UTF-8",
      "outencoding" => "UTF-8",
      "subdirmode" => nil,
    }
    ReVIEW.book.param = @param
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(nil, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)

    @builder.instance_eval do
      # to ignore lineno in original method
      def warn(msg)
        puts msg
      end
    end
  end

  def test_headline_level1
    result = @builder.headline(1,"test","this is test.\n")
    assert_equal %Q|■H1■第1章　this is test.\n|, result
  end

  def test_headline_level1_without_secno
    @param["secnolevel"] = 0
    result = @builder.headline(1,"test","this is test.\n")
    assert_equal %Q|■H1■this is test.\n|, result
  end

  def test_headline_level2
    result = @builder.headline(2,"test","this is test.\n")
    assert_equal %Q|■H2■1.1　this is test.\n|, result
  end

  def test_headline_level3
    result = @builder.headline(3,"test","this is test.\n")
    assert_equal %Q|■H3■this is test.\n|, result
  end

  def test_headline_level3_with_secno
    @param["secnolevel"] = 3
    result = @builder.headline(3,"test","this is test.\n")
    assert_equal %Q|■H3■1.0.1　this is test.\n|, result
  end

  def test_href
    ret = @builder.compile_href("http://github.com", "GitHub")
    assert_equal %Q|GitHub（△http://github.com☆）|, ret
  end

  def test_href_without_label
    ret = @builder.compile_href("http://github.com",nil)
    assert_equal %Q|△http://github.com☆|, ret
  end

  def test_inline_raw
    ret = @builder.inline_raw("@<tt>{inline}")
    assert_equal %Q|@<tt>{inline}|, ret
  end

  def test_inline_ruby
    ret = @builder.compile_ruby("coffin", "bed")
    assert_equal %Q|coffin◆→DTP連絡:「coffin」に「bed」とルビ←◆|, ret
  end

  def test_inline_kw
    result = compile_inline("@<kw>{ISO, International Organization for Standardization } @<kw>{Ruby<>}")
    assert_equal %Q|★ISO☆（International Organization for Standardization） ★Ruby<>☆|, result
  end

  def test_inline_maru
    result = compile_inline("@<maru>{1}@<maru>{20}@<maru>{A}@<maru>{z}")
    assert_equal %Q|1◆→丸数字1←◆20◆→丸数字20←◆A◆→丸数字A←◆z◆→丸数字z←◆|, result
  end

  def test_inline_br
    ret = @builder.inline_br("")
    assert_equal %Q|\n|, ret
  end

  def test_inline_i
    result = compile_inline("test @<i>{inline test} test2")
    assert_equal %Q|test ▲inline test☆ test2|, result
  end

  def test_inline_i_and_escape
    result = compile_inline("test @<i>{inline<&;\\ test} test2")
    assert_equal %Q|test ▲inline<&;\\ test☆ test2|, result
  end

  def test_inline_b
    result = compile_inline("test @<b>{inline test} test2")
    assert_equal %Q|test ★inline test☆ test2|, result
  end

  def test_inline_b_and_escape
    result = compile_inline("test @<b>{inline<&;\\ test} test2")
    assert_equal %Q|test ★inline<&;\\ test☆ test2|, result
  end

  def test_inline_tt
    result = compile_inline("test @<tt>{inline test} test2@<tt>{\\}}")
    assert_equal %Q|test △inline test☆ test2△}☆|, result
  end

  def test_inline_tti
    result = compile_inline("test @<tti>{inline test} test2")
    assert_equal %Q|test ▲inline test☆◆→等幅フォントイタ←◆ test2|, result
  end

  def test_inline_ttb
    result = compile_inline("test @<ttb>{inline test} test2")
    assert_equal %Q|test ★inline test☆◆→等幅フォント太字←◆ test2|, result
  end

  def test_inline_uchar
    result = compile_inline("test @<uchar>{2460} test2")
    assert_equal %Q|test ① test2|, result
  end

  def test_inline_in_table
    result = @builder.table(["★1☆\t▲2☆", "------------", "★3☆\t▲4☆<>&"])
    assert_equal %Q|★★1☆☆\t★▲2☆☆\n★3☆\t▲4☆<>&\n◆→終了:表←◆\n\n|, result
  end

  def test_paragraph
    lines = ["foo","bar"]
    result = @builder.paragraph(lines)
    assert_equal %Q|foobar\n|, result
  end

  def test_tabbed_paragraph
    lines = ["\tfoo","bar"]
    result = @builder.paragraph(lines)
    assert_equal %Q|\tfoobar\n|, result
  end

  def test_flushright
    result = @builder.flushright(["foo", "bar", "","buz"])
    assert_equal %Q|◆→開始:右寄せ←◆\nfoobar\nbuz\n◆→終了:右寄せ←◆\n\n|, result
  end

  def test_noindent
    result = ""
    result << @builder.noindent
    result << @builder.paragraph(["foo", "bar"])
    result << @builder.paragraph(["foo2", "bar2"])
    assert_equal %Q|◆→DTP連絡:次の1行インデントなし←◆\nfoobar\nfoo2bar2\n|, result
  end

  def test_list
    def @chapter.list(id)
      Book::ListIndex::Item.new("test",1)
    end
    result = compile_blockelem("//list[test][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    assert_equal %Q|◆→開始:リスト←◆\nリスト1.1　this is ★test☆<&>_\n\nfoo\nbar\n◆→終了:リスト←◆\n\n|, result
  end

  def test_listnum
    def @chapter.list(id)
      Book::ListIndex::Item.new("test",1)
    end
    result = compile_blockelem("//listnum[test][this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    assert_equal %Q|◆→開始:リスト←◆\nリスト1.1　this is ★test☆<&>_\n\n 1: foo\n 2: bar\n◆→終了:リスト←◆\n\n|, result
  end

  def test_emlistnum
    result = compile_blockelem("//emlistnum[this is @<b>{test}<&>_]{\nfoo\nbar\n//}\n")
    assert_equal %Q|◆→開始:インラインリスト←◆\n■this is ★test☆<&>_\n 1: foo\n 2: bar\n◆→終了:インラインリスト←◆\n\n|, result
  end

  def test_image
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    result = @builder.image(["foo"], "sampleimg","sample photo",nil)
    assert_equal %Q|◆→開始:図←◆\n図1.1　sample photo\n\n◆→./images/chap1-sampleimg.png←◆\n◆→終了:図←◆\n\n|, result
  end

  def test_image_with_metric
    def @chapter.image(id)
      item = Book::ImageIndex::Item.new("sampleimg",1)
      item.instance_eval{@pathes=["./images/chap1-sampleimg.png"]}
      item
    end

    result = @builder.image(["foo"], "sampleimg","sample photo","scale=1.2")
    assert_equal %Q|◆→開始:図←◆\n図1.1　sample photo\n\n◆→./images/chap1-sampleimg.png←◆\n◆→終了:図←◆\n\n|, result
  end

  def test_texequation
    result = @builder.texequation(["\\sin", "1^{2}"])
    assert_equal %Q|◆→開始:TeX式←◆\n\\sin\n1^{2}\n◆→終了:TeX式←◆\n\n|, result
  end

  def test_inline_raw0
    assert_equal "normal", @builder.inline_raw("normal")
  end

  def test_inline_raw1
    assert_equal "body", @builder.inline_raw("|top|body")
  end

  def test_inline_raw2
    assert_equal "body", @builder.inline_raw("|top, latex|body")
  end

  def test_inline_raw3
    assert_equal "", @builder.inline_raw("|idgxml, html|body")
  end

  def test_inline_raw4
    assert_equal "|top body", @builder.inline_raw("|top body")
  end

  def test_inline_raw5
    assert_equal "nor\nmal", @builder.inline_raw("|top|nor\\nmal")
  end

  def test_block_raw0
    result = @builder.raw("<>!\"\\n& ")
    expect =<<-EOS
<>!"
& 
EOS
    assert_equal expect.chomp, result
  end

  def test_block_raw1
    result = @builder.raw("|top|<>!\"\\n& ")
    expect =<<-EOS
<>!"
& 
EOS
    assert_equal expect.chomp, result
  end

  def test_block_raw2
    result = @builder.raw("|top, latex|<>!\"\\n& ")
    expect =<<-EOS
<>!\"
& 
EOS
    assert_equal expect.chomp, result
  end

  def test_block_raw3
    result = @builder.raw("|latex, idgxml|<>!\"\\n& ")
    expect =<<-EOS
EOS
    assert_equal expect.chomp, result
  end

  def test_block_raw4
    result = @builder.raw("|top <>!\"\\n& ")
    expect =<<-EOS
|top <>!\"
& 
EOS
    assert_equal expect.chomp, result
  end

end
