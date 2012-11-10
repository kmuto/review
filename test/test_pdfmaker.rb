# encoding: utf-8

require 'test_helper'
require 'tmpdir'
require 'fileutils'

load File.expand_path('../bin/review-pdfmaker', File.dirname(__FILE__))

class PDFMakerTest < Test::Unit::TestCase
  def setup
    @tmpdir1 = Dir.mktmpdir
    @tmpdir2 = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf @tmpdir1
    FileUtils.rm_rf @tmpdir2
  end

  def test_copyImagesToDir
    types = %w{png gif jpg jpeg svg pdf eps PNG GIF JPG JPEG SVG PDF EPS}
    types.each do |type|
      touch_file("#{@tmpdir1}/foo.#{type}")
    end
    copyImagesToDir(@tmpdir1, @tmpdir2)

    types.each do |type|
      assert File.exists?("#{@tmpdir2}/foo.#{type}"), "Copying #{type} file failed"
    end
  end

  private
  def touch_file(path)
    File.open(path, "w").close
    path
  end
end
