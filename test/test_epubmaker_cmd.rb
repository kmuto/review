# encoding: utf-8

require 'test_helper'
require 'tmpdir'
require 'fileutils'

REVIEW_EPUBMAKER = File.expand_path('../bin/review-epubmaker', File.dirname(__FILE__))

load REVIEW_EPUBMAKER

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
    config = prepare_samplebook(@tmpdir1)
    builddir = @tmpdir1 + "/" + config['bookname'] + '-epub'
    assert ! File.exists?(builddir)

    Dir.chdir(@tmpdir1) do
      system("#{REVIEW_EPUBMAKER} config.yml 1>/dev/null 2>/dev/null")
    end

    assert File.exists?(builddir)
  end
end
