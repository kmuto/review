require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'rbconfig'
require 'zip'

REVIEW_EPUBMAKER = File.expand_path('../bin/review-epubmaker', __dir__)

class EPUBMakerCmdTest < Test::Unit::TestCase
  def setup
    @tmpdir1 = Dir.mktmpdir

    @old_rubylib = ENV['RUBYLIB']
    ENV['RUBYLIB'] = File.expand_path('lib', __dir__)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir1)
    ENV['RUBYLIB'] = @old_rubylib
  end

  def common_buildepub(bookdir, configfile, targetepubfile)
    if /mswin|mingw|cygwin/ !~ RUBY_PLATFORM
      config = prepare_samplebook(@tmpdir1, bookdir, nil, configfile)
      builddir = File.join(@tmpdir1, config['bookname'] + '-epub')
      assert !File.exist?(builddir)

      ruby_cmd = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']) + RbConfig::CONFIG['EXEEXT']
      Dir.chdir(@tmpdir1) do
        system("#{ruby_cmd} -S #{REVIEW_EPUBMAKER} #{configfile} 1>/dev/null 2>/dev/null")
      end
      assert File.exist?(File.join(@tmpdir1, targetepubfile))
    end
  end

  def check_filesize(epubfile)
    if /mswin|mingw|cygwin/ !~ RUBY_PLATFORM
      Zip::File.open(epubfile) do |zio|
        zio.each do |entry|
          assert_not_equal(0, entry.size, "#{entry.name} is 0 byte.")
        end
      end
    end
  end

  def test_epubmaker_cmd_samplebook
    common_buildepub('sample-book/src', 'config.yml', 'book.epub')
    check_filesize(File.join(@tmpdir1, 'book.epub'))
  end

  def test_epubmaker_cmd_syntaxbook
    common_buildepub('syntax-book', 'config.yml', 'syntax-book.epub')
    check_filesize(File.join(@tmpdir1, 'syntax-book.epub'))
  end
end
