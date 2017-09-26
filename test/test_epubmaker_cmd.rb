require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'rbconfig'

REVIEW_EPUBMAKER = File.expand_path('../bin/review-epubmaker', File.dirname(__FILE__))

class EPUBMakerCmdTest < Test::Unit::TestCase
  def setup
    @tmpdir1 = Dir.mktmpdir
    @tmpdir2 = Dir.mktmpdir

    @old_rubylib = ENV['RUBYLIB']
    ENV['RUBYLIB'] = File.expand_path('../lib', File.dirname(__FILE__))
  end

  def teardown
    FileUtils.rm_rf @tmpdir1
    FileUtils.rm_rf @tmpdir2
    ENV['RUBYLIB'] = @old_rubylib
  end

  def test_epubmaker_cmd
    if /mswin|mingw|cygwin/ !~ RUBY_PLATFORM
      config = prepare_samplebook(@tmpdir1)
      builddir = @tmpdir1 + '/' + config['bookname'] + '-epub'
      assert !File.exist?(builddir)

      ruby_cmd = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']) + RbConfig::CONFIG['EXEEXT']
      Dir.chdir(@tmpdir1) do
        system("#{ruby_cmd} -S #{REVIEW_EPUBMAKER} config.yml 1>/dev/null 2>/dev/null")
      end

      assert File.exist?(builddir)
    end
  end
end
