require 'test_helper'
require 'review/pdfmaker'

class PDFMakerTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @maker = ReVIEW::PDFMaker.new
    @config = ReVIEW::Configure.values
    @config.merge!(
      'bookname' => 'sample',
      'title' => 'Sample Book',
      'version' => 2,
      'urnid' => 'http://example.jp/',
      'date' => '2011-01-01',
      'language' => 'ja',
      'texcommand' => 'uplatex'
    )
    @maker.config = @config
    @maker.initialize_metachars(@config['texcommand'])
    @output = StringIO.new
    I18n.setup(@config['language'])
  end

  def test_check_book_existed
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        pdf_file = File.join(dir, 'sample.pdf')
        FileUtils.touch(pdf_file)
        @maker.basedir = Dir.pwd
        @maker.remove_old_file
        assert !File.exist?(pdf_file)
      end
    end
  end

  def test_check_book_none
    Dir.mktmpdir do
      assert_nothing_raised do
        @maker.basedir = Dir.pwd
        @maker.remove_old_file
      end
    end
  end

  def test_buildpath_debug
    @maker.config['debug'] = true
    path = @maker.build_path
    begin
      assert_equal(path, 'sample-pdf')
    ensure
      FileUtils.remove_entry_secure path
    end
  end

  def test_parse_opts_help
    io = StringIO.new
    $stdout = io
    assert_raises SystemExit do
      @maker.parse_opts(['-h'])
    end
    $stdout = STDOUT
    io.rewind
    str = io.gets
    assert_equal "Usage: review-pdfmaker configfile\n", str
  end

  def test_parse_opts_ignore_errors
    conf, yml = @maker.parse_opts(['--ignore-errors', 'hoge.yml'])
    assert_equal conf['ignore-errors'], true
    assert_equal yml, 'hoge.yml'
  end

  def test_make_custom_page
    Dir.mktmpdir do |dir|
      coverfile = 'cover.html'
      content = '<html><body>test</body></html>'
      File.open(File.join(dir, 'cover.tex'), 'w') { |f| f.write(content) }
      page = @maker.make_custom_page(File.join(dir, coverfile))
      assert_equal(content, page)
    end
  end

  def test_make_authors
    @config.merge!(
      'aut' => ['テスト太郎', 'テスト次郎'],
      'csl' => ['監修三郎'],
      'trl' => ['翻訳四郎', '翻訳五郎']
    )
    Dir.mktmpdir do
      authors = @maker.make_authors
      assert_equal("テスト太郎、テスト次郎　著 \\\\\n監修三郎　監修 \\\\\n翻訳四郎、翻訳五郎　訳",
                   authors)
    end
  end

  def test_make_authors_only_aut
    @config['aut'] = 'テスト太郎'
    Dir.mktmpdir do
      authors = @maker.make_authors
      assert_equal('テスト太郎　著', authors)
    end
  end

  def test_make_okuduke
    @config.merge!(
      'aut' => ['テスト太郎', 'テスト次郎'],
      'csl' => ['監修三郎'],
      'trl' => ['翻訳四郎', '翻訳五郎'],
      'dsr' => ['デザイン六郎'],
      'ill' => ['イラスト七郎', 'イラスト八郎'],
      'cov' => ['表紙九郎'],
      'edt' => ['編集十郎'],
      'pbl' => 'テスト出版',
      'prt' => 'テスト印刷'
    )
    Dir.mktmpdir do
      okuduke = @maker.make_colophon
      assert_equal("著　者 & テスト太郎、テスト次郎 \\\\\n監　修 & 監修三郎 \\\\\n翻　訳 & 翻訳四郎、翻訳五郎 \\\\\nデザイン & デザイン六郎 \\\\\nイラスト & イラスト七郎、イラスト八郎 \\\\\n表　紙 & 表紙九郎 \\\\\n編　集 & 編集十郎 \\\\\n発行所 & テスト出版 \\\\\n印刷所 & テスト印刷 \\\\\n",
                   okuduke)
    end
  end

  def test_make_okuduke_dojin
    @config.merge!(
      'aut' => ['テスト太郎', 'テスト次郎'],
      'csl' => ['監修三郎'],
      'ill' => ['イラスト七郎', 'イラスト八郎'],
      'pbl' => 'テスト出版',
      'prt' => 'テスト印刷',
      'contact' => 'tarou@example.jp'
    )
    Dir.mktmpdir do
      I18n.update({ 'prt' => '印刷所' }, 'ja')
      okuduke = @maker.make_colophon
      assert_equal("著　者 & テスト太郎、テスト次郎 \\\\\n監　修 & 監修三郎 \\\\\nイラスト & イラスト七郎、イラスト八郎 \\\\\n発行所 & テスト出版 \\\\\n連絡先 & tarou@example.jp \\\\\n印刷所 & テスト印刷 \\\\\n",
                   okuduke)
    end
  end

  def test_template_content
    Dir.mktmpdir do
      @maker.basedir = Dir.pwd
      tmpl = @maker.template_content
      expect = File.read(File.join(assets_dir, 'test_template.tex'))
      assert_equal(expect, tmpl)
    end
  end

  def test_gettemplate_with_backmatter
    @config.merge!(
      'backcover' => 'backcover.html',
      'profile' => 'profile.html',
      'advfile' => 'advfile.html'
    )
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        profile = "\\thispagestyle{empty}\\chapter*{Profile}\nsome profile\n"
        File.open(File.join(dir, 'profile.tex'), 'w') { |f| f.write(profile) }
        advfile = "\\thispagestyle{empty}\\chapter*{Ad}\nsome ad content\n"
        File.open(File.join(dir, 'advfile.tex'), 'w') { |f| f.write(advfile) }
        backcover = "\\clearpage\n\\thispagestyle{empty}\\AddToShipoutPictureBG{%\n\\AtPageLowerLeft{\\includegraphics[width=\\paperwidth,height=\\paperheight]{images/backcover.png}}\n}\n\\null"
        File.open(File.join(dir, 'backcover.tex'), 'w') { |f| f.write(backcover) }

        expect = File.read(File.join(assets_dir, 'test_template_backmatter.tex'))

        @maker.basedir = Dir.pwd
        tmpl = @maker.template_content
        tmpl.gsub!(/\A.*%% backmatter begins\n/m, '')
        assert_equal(expect, tmpl)
      end
    end
  end

  def test_colophon_history
    @config['aut'] = ['Mr.Smith']
    @config['pbl'] = ['BLUEPRINT']
    @config['pht'] = ['Mrs.Smith']
    @config['language'] = 'ja'
    history = @maker.make_history_list
    expect = ['2011年1月1日　発行']
    assert_equal expect, history
  end

  def test_colophon_history_2
    @config['aut'] = ['Mr.Smith']
    @config['pbl'] = ['BLUEPRINT']
    @config['pht'] = ['Mrs.Smith']
    @config['language'] = 'ja'
    @config['history'] =
      [['2011-08-03 v1.0.0版発行',
        '2012-02-15 v1.1.0版発行']]
    history = @maker.make_history_list
    expect = ['2011年8月3日　v1.0.0版発行', '2012年2月15日　v1.1.0版発行']
    assert_equal expect, history
  end

  def test_colophon_history_date
    @config['aut'] = ['Mr.Smith']
    @config['pbl'] = ['BLUEPRINT']
    @config['pht'] = ['Mrs.Smith']
    @config['language'] = 'ja'
    @config['history'] =
      [['2011-08-03',
        '2012-02-15']]
    history = @maker.make_history_list
    expect = ['2011年8月3日　初版第1刷　発行',
              '2012年2月15日　初版第2刷　発行']
    assert_equal expect, history
  end

  def test_colophon_history_date2
    @config['aut'] = ['Mr.Smith']
    @config['pbl'] = ['BLUEPRINT']
    @config['pht'] = ['Mrs.Smith']
    @config['language'] = 'ja'
    @config['history'] =
      [['2011-08-03',
        '2012-02-15'],
       ['2012-10-01'],
       ['2013-03-01']]
    history = @maker.make_history_list
    expect = ['2011年8月3日　初版第1刷　発行',
              '2012年2月15日　初版第2刷　発行',
              '2012年10月1日　第2版第1刷　発行',
              '2013年3月1日　第3版第1刷　発行']
    assert_equal expect, history
  end

  def test_colophon_history_freeformat
    @config['aut'] = ['Mr.Smith']
    @config['pbl'] = ['BLUEPRINT']
    @config['pht'] = ['Mrs.Smith']
    @config['language'] = 'ja'
    @config['history'] =
      [['2011年8月3日 ver 1.1.0発行'],
       ['2011年10月12日 ver 1.2.0発行'],
       ['2012年1月31日 ver 1.2.1発行']]
    history = @maker.make_history_list
    expect = ['2011年8月3日 ver 1.1.0発行',
              '2011年10月12日 ver 1.2.0発行',
              '2012年1月31日 ver 1.2.1発行']
    assert_equal expect, history
  end
end
