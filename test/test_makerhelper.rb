# -*- coding: utf-8 -*-

require 'test_helper'
require 'review/makerhelper'
require 'tmpdir'
require 'fileutils'


class MakerHelperTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    @tmpdir1 = Dir.mktmpdir
    @tmpdir2 = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf @tmpdir1
    FileUtils.rm_rf @tmpdir2
  end

  def test_copy_images_to_dir
    types = %w{png gif jpg jpeg svg pdf eps PNG GIF JPG JPEG SVG PDF EPS}
    types.each do |type|
      touch_file("#{@tmpdir1}/foo.#{type}")
    end
    FileUtils.mkdir("#{@tmpdir1}/subdir")
    touch_file("#{@tmpdir1}/subdir/foo.png")

    image_files = MakerHelper.copy_images_to_dir(@tmpdir1, @tmpdir2)

    types.each do |type|
      assert File.exists?("#{@tmpdir2}/foo.#{type}"), "Copying #{type} file failed"
      assert image_files.include?("#{@tmpdir1}/foo.#{type}")
    end
    assert File.exists?("#{@tmpdir2}/subdir/foo.png"), "Copying a image file in a subdirectory"
    assert image_files.include?("#{@tmpdir1}/subdir/foo.png")
  end

  def test_copy_images_to_dir_convert
    touch_file("#{@tmpdir1}/foo.eps")

    image_files = MakerHelper.copy_images_to_dir(@tmpdir1, @tmpdir2,
                                                 :convert => {:eps => :png})

    assert File.exists?("#{@tmpdir2}/foo.eps.png"), "EPS to PNG conversion failed"
    assert image_files.include?("#{@tmpdir1}/foo.eps.png")
  end

end
