require 'test_helper'
require 'review/update'
require 'tmpdir'
require 'fileutils'

class UpdateTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @tmpdir = Dir.mktmpdir
    @u = Update.new
    @u.force = true
    I18n.setup('en')
  end

  def teardown
    FileUtils.rm_rf @tmpdir
  end

  def test_broken_yml
    File.write(File.join(@tmpdir, 'test.yml'), "invalid: [,]\n")
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    assert_match(/test\.yml is broken\. Ignored\./, io.string)
  end

  def test_rewrite_yml
    File.write(File.join(@tmpdir, 'test.yml'), "key: foo1\n  key: foo2\n\t\t  key: foo3\nakey: foo3\nkeya: foo4\n")
    @u.rewrite_yml(File.join(@tmpdir, 'test.yml'), 'key', 'val')
    cont = <<EOT
key: val
  key: val
		  key: val
akey: foo3
keya: foo4
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'test.yml'))
  end

  def test_yml_variation
    File.write(File.join(@tmpdir, 'config.yml'), "review_version: 2.0\nlanguage: en\n")
    File.write(File.join(@tmpdir, 'tex1.yml'), %Q(review_version: 2.0\ntexdocumentclass: ["jsbook", "uplatex,twoside"]\n))
    File.write(File.join(@tmpdir, 'epub1.yml'), "htmlversion: 4\nepubversion: 2\n")
    File.write(File.join(@tmpdir, 'locale.yml'), "locale: ja\n")
    File.write(File.join(@tmpdir, 'locale2.yml'), "locale: en\n")
    File.write(File.join(@tmpdir, 'catalog.yml'), "PREDEF:\n  - pr01.re\n")
    File.write(File.join(@tmpdir, 'catalog2.yml'), "CHAPS:\n  - ch01.re\n")
    File.write(File.join(@tmpdir, 'catalog3.yml'), "APPENDIX:\n  - app01.re\n")

    @u.parse_ymls(@tmpdir)

    assert_equal 2, @u.config_ymls.size
    assert_equal 2, @u.locale_ymls.size
    assert_equal 3, @u.catalog_ymls.size
    assert_equal 1, @u.tex_ymls.size
    assert_equal 1, @u.epub_ymls.size
  end

  def test_check_old_catalogs
    %w[PREDEF CHAPS POSTDEF PART].each do |fname|
      File.write(File.join(@tmpdir, fname), '')

      io = StringIO.new
      @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
      assert_raise(ApplicationError) { @u.check_old_catalogs(@tmpdir) }
      assert_match(/review\-catalog\-converter/, io.string)

      File.unlink(File.join(@tmpdir, fname))
    end
  end

  def test_check_own_files_layout
    Dir.mkdir(File.join(@tmpdir, 'layouts'))
    File.write(File.join(@tmpdir, 'layouts/layout.tex.erb'), '')

    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    assert_raise(ApplicationError) { @u.check_own_files(@tmpdir) }
    assert_match(%r{There is custom layouts/layout\.tex\.erb file}, io.string)
  end

  def test_check_own_files_reviewext
    File.write(File.join(@tmpdir, 'review-ext.rb'), '')

    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.check_own_files(@tmpdir)
    assert_match(/There is review\-ext\.rb file/, io.string)
  end

  def test_update_version_older
    File.write(File.join(@tmpdir, 'config.yml'), "review_version: 2.0\n")

    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_version
    assert_match(/Update 'review_version' to '3.0'/, io.string)
    assert_equal 'review_version: 3.0', File.read(File.join(@tmpdir, 'config.yml')).match(/review_version:.*$/).to_s
  end

  def test_update_version_current
    File.write(File.join(@tmpdir, 'config.yml'), "review_version: 3.0\n")

    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_version
    assert_equal '', io.string
    assert_equal 'review_version: 3.0', File.read(File.join(@tmpdir, 'config.yml')).match(/review_version:.*$/).to_s
  end

  def test_update_version_newer
    File.write(File.join(@tmpdir, 'config.yml'), "review_version: 99.0\n")

    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_version
    assert_match(/Update 'review_version' to '3.0'/, io.string)
    assert_equal 'review_version: 99.0', File.read(File.join(@tmpdir, 'config.yml')).match(/review_version:.*$/).to_s
  end

  def test_update_rakefile
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.update_rakefile(@tmpdir)
    assert_equal '', io.string
    assert_equal true, File.exist?(File.join(@tmpdir, 'Rakefile'))
    assert_equal true, File.exist?(File.join(@tmpdir, 'lib/tasks/review.rake'))
  end

  def test_update_rakefile_same
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.update_rakefile(@tmpdir)
    @u.update_rakefile(@tmpdir)
    assert_equal '', io.string
    assert_equal true, File.exist?(File.join(@tmpdir, 'Rakefile'))
    assert_equal true, File.exist?(File.join(@tmpdir, 'lib/tasks/review.rake'))
  end

  def test_update_rakefile_different
    File.write(File.join(@tmpdir, 'Rakefile'), '')
    FileUtils.mkdir_p File.join(@tmpdir, 'lib/tasks')
    File.write(File.join(@tmpdir, 'lib/tasks/review.rake'), '')
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.update_rakefile(@tmpdir)
    assert_match(/Rakefile will be overridden with/, io.string)
    assert_match(%r{lib/tasks/review\.rake will be overridden}, io.string)
    assert_equal true, File.exist?(File.join(@tmpdir, 'Rakefile'))
    assert_equal true, File.exist?(File.join(@tmpdir, 'lib/tasks/review.rake'))
  end

  def test_update_epub_version_older
    File.write(File.join(@tmpdir, 'config.yml'), "epubversion: 2\nhtmlversion: 4\n")
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_epub_version
    assert_match(/Update 'epubversion'/, io.string)
    assert_match(/Update 'htmlversion'/, io.string)
    cont = <<EOT
epubversion: 3
htmlversion: 5
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_epub_version_current
    File.write(File.join(@tmpdir, 'config.yml'), "epubversion: 3\nhtmlversion: 5\n")
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_epub_version
    assert_equal '', io.string
    cont = <<EOT
epubversion: 3
htmlversion: 5
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_epub_version_newer
    File.write(File.join(@tmpdir, 'config.yml'), "epubversion: 99\nhtmlversion: 99\n")
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_epub_version
    assert_equal '', io.string
    cont = <<EOT
epubversion: 99
htmlversion: 99
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_locale_older
    File.write(File.join(@tmpdir, 'locale.yml'), %Q(locale: en\nchapter_quote: "'%s'"\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_locale
    assert_match(/'chapter_quote' now takes 2 values/, io.string)
    cont = <<EOT
locale: en
chapter_quote: '%s %s'
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'locale.yml'))
  end

  def test_update_locale_current
    File.write(File.join(@tmpdir, 'locale.yml'), %Q(locale: en\nchapter_quote: "'%s...%s'"\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_locale
    assert_equal '', io.string
    cont = <<EOT
locale: en
chapter_quote: "'%s...%s'"
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'locale.yml'))
  end

  def test_update_tex_parameters_jsbook_to_review_jsbook
    File.write(File.join(@tmpdir, 'config.yml'), %Q(texdocumentclass: ["jsbook", "a5j,11pt,landscape,oneside,twoside,vartwoside,onecolumn,twocolumn,titlepage,notitlepage,openright,openany,leqno,fleqn,disablejfam,draft,final,mingoth,winjis,jis,papersize,english,report,jslogo,nojslogo,uplatex,nomag,usemag,nomag*,tombow,tombo,mentuke,autodetect-engine"]\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_tex_parameters
    assert_match(/By default it is migrated to/, io.string)
    assert_match(/is safely replaced/, io.string)
    cont = <<EOT
texdocumentclass: ["review-jsbook", "paper=a5,Q=15.46,landscape,oneside,twoside,vartwoside,onecolumn,twocolumn,titlepage,notitlepage,openright,openany,leqno,fleqn,disablejfam,draft,final,mingoth,winjis,jis,papersize,english,report,jslogo,nojslogo,cameraready=print,cover=false"]
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_tex_parameters_jsbook_to_review_jsbook_invalid
    File.write(File.join(@tmpdir, 'config.yml'), %Q(texdocumentclass: ["jsbook", "a5paper,invalid"]\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_tex_parameters
    assert_match(/couldn't be converted fully/, io.string)
    assert_match("'paper=a5,cameraready=print,cover=false' is suggested", io.string)
    cont = <<EOT
texdocumentclass: ["jsbook", "a5paper,invalid"]
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_tex_parameters_review_jsbook
    File.write(File.join(@tmpdir, 'config.yml'), %Q(texdocumentclass: ["review-jsbook", ""]\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_tex_parameters
    assert_equal '', io.string
    cont = <<EOT
texdocumentclass: ["review-jsbook", ""]
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_tex_parameters_review_jlreq
    File.write(File.join(@tmpdir, 'config.yml'), %Q(texdocumentclass: ["review-jlreq", ""]\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_tex_parameters
    assert_equal '', io.string
    cont = <<EOT
texdocumentclass: ["review-jlreq", ""]
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_tex_parameters_review_jsbook_review_jlreq
    File.write(File.join(@tmpdir, 'config.yml'), %Q(texdocumentclass: ["review-jsbook", ""]\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.specified_template = 'review-jlreq'
    @u.update_tex_parameters
    assert_match(/already, but you specified/, io.string)
    cont = <<EOT
texdocumentclass: ["review-jsbook", ""]
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_tex_parameters_unknownclass
    File.write(File.join(@tmpdir, 'config.yml'), %Q(texdocumentclass: ["unknown", ""]\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_tex_parameters
    assert_match(/unknown class/, io.string)
    cont = <<EOT
texdocumentclass: ["unknown", ""]
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_tex_parameters_jsbook_unknownclass
    File.write(File.join(@tmpdir, 'config.yml'), %Q(texdocumentclass: ["jsbook", ""]\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.specified_template = 'unknown'
    @u.update_tex_parameters
    assert_match(/unknown class/, io.string)
    cont = <<EOT
texdocumentclass: ["jsbook", ""]
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_tex_parameters_jsbook_to_review_jlreq
    File.write(File.join(@tmpdir, 'config.yml'), %Q(texdocumentclass: ["jsbook", "a5j,11pt,landscape,oneside,twoside,onecolumn,twocolumn,titlepage,notitlepage,openright,openany,leqno,fleqn,draft,final,report,uplatex,nomag,usemag,nomag*,tombow,tombo,mentuke,autodetect-engine"]\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.specified_template = 'review-jlreq'
    @u.update_tex_parameters
    assert_match(/By default it is migrated to/, io.string)
    assert_match(/is safely replaced/, io.string)
    cont = <<EOT
texdocumentclass: ["review-jlreq", "paper=a5,fontsize=11pt,landscape,oneside,twoside,onecolumn,twocolumn,titlepage,notitlepage,openright,openany,leqno,fleqn,draft,final,report,cameraready=print,cover=false"]
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_stys_new
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.update_tex_stys('review-jsbook', @tmpdir)
    assert_equal '', io.string
    assert_equal true, File.exist?(File.join(@tmpdir, 'sty/review-base.sty'))
    assert_equal true, File.exist?(File.join(@tmpdir, 'sty/gentombow09j.sty'))
  end

  def test_update_stys_new_custom
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.update_tex_stys('review-jsbook', @tmpdir)
    assert_equal '', io.string
    File.write(File.join(@tmpdir, 'sty/review-custom.sty'), "% MY CUSTOM\n")
    @u.update_tex_stys('review-jsbook', @tmpdir)
    assert_equal '', io.string
    assert_equal "% MY CUSTOM\n", File.read(File.join(@tmpdir, 'sty/review-custom.sty'))
  end

  def test_update_stys_modified
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.update_tex_stys('review-jsbook', @tmpdir)
    cont = File.read(File.join(@tmpdir, 'sty/review-base.sty'))

    File.write(File.join(@tmpdir, 'sty/review-base.sty'), "% MODIFIED\n")
    @u.update_tex_stys('review-jsbook', @tmpdir)
    assert_match(/review\-base\.sty will be overridden/, io.string)
    assert_equal cont, File.read(File.join(@tmpdir, 'sty/review-base.sty'))
  end

  def test_update_tex_command
    File.write(File.join(@tmpdir, 'config.yml'), %Q(texcommand: "/Program Files/up-latex --shell-escape -v"\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_tex_command
    assert_match(/has options/, io.string)
    cont = <<EOT
texcommand: "/Program Files/up-latex"
texoptions: "-interaction=nonstopmode -file-line-error --shell-escape -v"
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_tex_command_noopt
    File.write(File.join(@tmpdir, 'config.yml'), %Q(texcommand: "/Program Files/up-latex"\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_tex_command
    assert_equal '', io.string
    cont = <<EOT
texcommand: "/Program Files/up-latex"
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_tex_command_withopt
    File.write(File.join(@tmpdir, 'config.yml'), %Q(texcommand: "/Program Files/up-latex --shell-escape -v"\ntexoptions: "-myopt"\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_tex_command
    assert_match(/has options/, io.string)
    cont = <<EOT
texcommand: "/Program Files/up-latex"
texoptions: "-myopt --shell-escape -v"
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_dvi_command
    File.write(File.join(@tmpdir, 'config.yml'), %Q(dvicommand: "/Program Files/dvi-pdfmx -q --quiet"\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_dvi_command
    assert_match(/has options/, io.string)
    cont = <<EOT
dvicommand: "/Program Files/dvi-pdfmx"
dvioptions: "-d 5 -z 9 -q --quiet"
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_dvi_command_noopt
    File.write(File.join(@tmpdir, 'config.yml'), %Q(dvicommand: "/Program Files/dvi-pdfmx"\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_dvi_command
    assert_equal '', io.string
    cont = <<EOT
dvicommand: "/Program Files/dvi-pdfmx"
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end

  def test_update_dvi_command_withopt
    File.write(File.join(@tmpdir, 'config.yml'), %Q(dvicommand: "/Program Files/dvi-pdfmx -q --quiet"\ndvioptions: "-myopt"\n))
    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_dvi_command
    assert_match(/has options/, io.string)
    cont = <<EOT
dvicommand: "/Program Files/dvi-pdfmx"
dvioptions: "-myopt -q --quiet"
EOT
    assert_equal cont, File.read(File.join(@tmpdir, 'config.yml'))
  end
end
