# encoding: utf-8

require 'test_helper'
require 'tmpdir'
require 'fileutils'

REVIEW_PDFMAKER = File.expand_path('../bin/review-pdfmaker', File.dirname(__FILE__))

load REVIEW_PDFMAKER
alias :pdfmaker_copyImagesToDir :copyImagesToDir

class PDFMakerCmdTest < Test::Unit::TestCase
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

  def test_copyImagesToDir
    types = %w{png gif jpg jpeg svg pdf eps PNG GIF JPG JPEG SVG PDF EPS}
    types.each do |type|
      touch_file("#{@tmpdir1}/foo.#{type}")
    end
    pdfmaker_copyImagesToDir(@tmpdir1, @tmpdir2)

    types.each do |type|
      assert File.exists?("#{@tmpdir2}/foo.#{type}"), "Copying #{type} file failed"
    end
  end

  def test_pdfmaker_cmd
    config = prepare_samplebook(@tmpdir1)
    builddir = @tmpdir1 + "/" + config['bookname'] + '-pdf'
    assert ! File.exists?(builddir)

    Dir.chdir(@tmpdir1) do
      system("#{REVIEW_PDFMAKER} config.yml 1>/dev/null 2>/dev/null")
    end

    assert File.exists?(builddir)
  end

  private
  def touch_file(path)
    File.open(path, "w").close
    path
  end
end
