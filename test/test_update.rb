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

  def test_update_version_2
    File.write(File.join(@tmpdir, 'config.yml'), "review_version: 2.0\n")

    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_version
    assert_match(/Update 'review_version' to '3.0'/, io.string)
    assert_equal 'review_version: 3.0', File.read(File.join(@tmpdir, 'config.yml')).match(/review_version:.*$/).to_s
  end

  def test_update_version_3
    File.write(File.join(@tmpdir, 'config.yml'), "review_version: 3.0\n")

    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_version
    assert_equal '', io.string
    assert_equal 'review_version: 3.0', File.read(File.join(@tmpdir, 'config.yml')).match(/review_version:.*$/).to_s
  end

  def test_update_version_99
    File.write(File.join(@tmpdir, 'config.yml'), "review_version: 99.0\n")

    io = StringIO.new
    @u.instance_eval{ @logger = ReVIEW::Logger.new(io) }
    @u.parse_ymls(@tmpdir)
    @u.update_version
    assert_equal '', io.string
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
end
