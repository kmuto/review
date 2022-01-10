require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'rbconfig'
require 'open3'

REVIEW_TEXTMAKER = File.expand_path('../bin/review-textmaker', File.dirname(__FILE__))

class TEXTMakerCmdTest < Test::Unit::TestCase
  def setup
    @tmpdir1 = Dir.mktmpdir

    @old_rubylib = ENV['RUBYLIB']
    ENV['RUBYLIB'] = File.expand_path('../lib', File.dirname(__FILE__))
  end

  def teardown
    FileUtils.rm_rf(@tmpdir1)
    ENV['RUBYLIB'] = @old_rubylib
  end

  def common_buildtext(bookdir, configfile, targetfile, option)
    unless /mswin|mingw|cygwin/.match?(RUBY_PLATFORM)
      config = prepare_samplebook(@tmpdir1, bookdir, nil, configfile)
      builddir = File.join(@tmpdir1, config['bookname'] + '-text')
      assert !File.exist?(builddir)

      ruby_cmd = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']) + RbConfig::CONFIG['EXEEXT']
      Dir.chdir(@tmpdir1) do
        _o, e, s = Open3.capture3("#{ruby_cmd} -S #{REVIEW_TEXTMAKER} #{option} #{configfile}")
        if defined?(ReVIEW::TTYLogger)
          assert_match(/SUCCESS/, e)
        else
          assert_equal '', e
        end
        assert s.success?
      end
      assert File.exist?(File.join(@tmpdir1, targetfile))
    end
  end

  def test_textmaker_cmd_samplebook
    common_buildtext('sample-book/src', 'config.yml', 'book-text/ch01.txt', nil)
  end

  def test_textmaker_cmd_samplebook_plain
    common_buildtext('sample-book/src', 'config.yml', 'book-text/ch01.txt', '-n')
  end

  def test_textmaker_cmd_syntaxbook
    common_buildtext('syntax-book', 'config.yml', 'syntax-book-text/ch01.txt', nil)
  end

  def test_textmaker_cmd_syntaxbook_plain
    common_buildtext('syntax-book', 'config.yml', 'syntax-book-text/ch01.txt', '-n')
  end
end
