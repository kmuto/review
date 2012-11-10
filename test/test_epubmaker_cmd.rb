# encoding: utf-8

require 'test_helper'
require 'tmpdir'
require 'fileutils'

load File.expand_path('../bin/review-epubmaker', File.dirname(__FILE__))
alias :epubmaker_copyImagesToDir :copyImagesToDir

class EPUBMakerCmdTest < Test::Unit::TestCase
  def setup
    @tmpdir1 = Dir.mktmpdir
    @tmpdir2 = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf @tmpdir1
    FileUtils.rm_rf @tmpdir2
  end

  def test_copyImagesToDir
    types = %w{png gif jpg jpeg svg PNG GIF JPG JPEG SVG}
    types.each do |type|
      touch_file("#{@tmpdir1}/foo.#{type}")
    end
    @manifeststr = ""
    epubmaker_copyImagesToDir(@tmpdir1, @tmpdir2)

    types.each do |type|
      assert File.exists?("#{@tmpdir2}/foo.#{type}"), "Copying #{type} file failed"
    end
  end

  def test_copyImagesToDir_eps
    FileUtils.cp(File.expand_path("tiger.eps",  File.dirname(__FILE__)), "#{@tmpdir1}/tiger.eps")
    @manifeststr = ""
    epubmaker_copyImagesToDir(@tmpdir1, @tmpdir2)

    assert File.exists?("#{@tmpdir2}/tiger.eps.png"), "Converting eps file into png file failed"
  end

  private
  def touch_file(path)
    File.open(path, "w").close
    path
  end
end
