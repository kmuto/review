# encoding: utf-8

require 'test_helper'
require 'review/pdfmaker'

class PDFMakerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @maker = ReVIEW::PDFMaker.new
    @config = ReVIEW::Configure.values
    @config.merge!({
                     "bookname" => "sample",
                     "title" => "Sample Book",
                     "version" => 2,
                     "urnid" => "http://example.jp/",
                     "date" => "2011-01-01",
                     "language" => "ja",
                   })
    @output = StringIO.new
    I18n.setup(@config["language"])
  end

  def test_check_book_existed
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        pdf_file = File.join(dir, "sample.pdf")
        FileUtils.touch(pdf_file)
        @maker.check_book(@config)
        assert !File.exist?(pdf_file)
      end
    end
  end

  def test_check_book_none
    Dir.mktmpdir do |dir|
      assert_nothing_raised do
        @maker.check_book(@config)
      end
    end
  end

  def test_buildpath
    assert_equal(@maker.build_path(@config), "./sample-pdf")
  end

  def test_parse_opts_help
    io = StringIO.new
    $stdout = io
    assert_raises SystemExit do
      @maker.parse_opts(["-h"])
    end
    $stdout = STDOUT
    io.rewind
    str = io.gets
    assert_equal "Usage: review-pdfmaker configfile\n", str
  end

  def test_parse_opts_ignore_errors
    io = StringIO.new
    conf, yml = @maker.parse_opts(["--ignore-errors", "hoge.yml"])
    assert_equal conf["ignore-errors"], true
    assert_equal yml, "hoge.yml"
  end

  def test_make_custom_titlepage
    Dir.mktmpdir do |dir|
      coverfile = "cover.html"
      content = "<html><body>test</body></html>"
      File.open(File.join(dir, "cover.tex"),"w"){|f| f.write(content) }
      page = @maker.make_custom_titlepage(File.join(dir, coverfile))
      assert_equal(content, page)
    end
  end

  def test_make_authors
    @config.merge!({"aut"=>["テスト太郎","テスト次郎"],
            "csl"=>["監修三郎"],
            "trl"=>["翻訳四郎","翻訳五郎",]})
    Dir.mktmpdir do |dir|
      authors = @maker.make_authors(@config)
      assert_equal("テスト太郎、テスト次郎　著 \\\\\n監修三郎　監修 \\\\\n翻訳四郎、翻訳五郎　訳",
                   authors)
    end
  end

  def test_make_authors_only_aut
    @config.merge!({"aut"=>"テスト太郎"})
    Dir.mktmpdir do |dir|
      authors = @maker.make_authors(@config)
      assert_equal("テスト太郎　著", authors)
    end
  end

  def test_make_okuduke
    @config.merge!({
      "aut"=>["テスト太郎","テスト次郎"],
      "csl"=>["監修三郎"],
      "trl"=>["翻訳四郎","翻訳五郎"],
      "dsr"=>["デザイン六郎"],
      "ill"=>["イラスト七郎","イラスト八郎"],
      "cov"=>["表紙九郎"],
      "edt"=>["編集十郎"],
      "prt"=>"テスト出版",
    })
    Dir.mktmpdir do |dir|
      okuduke = @maker.make_colophon(@config)
      assert_equal("著　者 & テスト太郎、テスト次郎 \\\\\n監　修 & 監修三郎 \\\\\n翻　訳 & 翻訳四郎、翻訳五郎 \\\\\nデザイン & デザイン六郎 \\\\\nイラスト & イラスト七郎、イラスト八郎 \\\\\n表　紙 & 表紙九郎 \\\\\n編　集 & 編集十郎 \\\\\n発行所 & テスト出版 \\\\\n",
                   okuduke)
    end
  end


  def test_make_okuduke_dojin
    @config.merge!({
      "aut"=>["テスト太郎","テスト次郎"],
      "csl"=>["監修三郎"],
      "ill"=>["イラスト七郎","イラスト八郎"],
      "pbl"=>"テスト出版",
      "prt"=>"テスト印刷",
      "contact"=>"tarou@example.jp",
    })
    Dir.mktmpdir do |dir|
      I18n.update({"prt" => "印刷所"},"ja")
      okuduke = @maker.make_colophon(@config)
      assert_equal("著　者 & テスト太郎、テスト次郎 \\\\\n監　修 & 監修三郎 \\\\\nイラスト & イラスト七郎、イラスト八郎 \\\\\n発行所 & テスト出版 \\\\\n連絡先 & tarou@example.jp \\\\\n印刷所 & テスト印刷 \\\\\n",
                   okuduke)
    end
  end

end
