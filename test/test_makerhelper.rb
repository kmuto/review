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
    types = %w[png gif jpg jpeg svg pdf eps]
    types.each { |type| touch_file("#{@tmpdir1}/foo.#{type}") }
    FileUtils.mkdir("#{@tmpdir1}/subdir")
    touch_file("#{@tmpdir1}/subdir/foo.png")

    image_files = MakerHelper.copy_images_to_dir(@tmpdir1, @tmpdir2)

    types.each do |type|
      assert File.exist?("#{@tmpdir2}/foo.#{type}"), "Copying #{type} file failed"
      assert image_files.include?("#{@tmpdir1}/foo.#{type}")
    end
    assert File.exist?("#{@tmpdir2}/subdir/foo.png"), 'Copying a image file in a subdirectory'
    assert image_files.include?("#{@tmpdir1}/subdir/foo.png")
  end

  def test_copy_images_to_dir_convert
    if /mswin|mingw|cygwin/ !~ RUBY_PLATFORM && (`convert -version` rescue nil) && (`gs --version` rescue nil)
      FileUtils.cp File.join(assets_dir, 'black.eps'), File.join(@tmpdir1, 'foo.eps')

      image_files = MakerHelper.copy_images_to_dir(@tmpdir1, @tmpdir2,
                                                   convert: { eps: :png })

      assert File.exist?("#{@tmpdir2}/foo.eps.png"), 'EPS to PNG conversion failed'
      assert image_files.include?("#{@tmpdir1}/foo.eps.png")
    end
  end

  def test_copy_images_to_dir_with_exts
    types = %w[png gif jpg jpeg svg pdf eps]
    types4epub = %w[png gif jpg jpeg svg]
    types.each { |type| touch_file("#{@tmpdir1}/foo.#{type}") }
    image_files = MakerHelper.copy_images_to_dir(@tmpdir1, @tmpdir2, exts: types4epub)

    types4epub.each { |type| assert image_files.include?("#{@tmpdir1}/foo.#{type}"), "foo.#{type} is not included" }
    (types - types4epub).each { |type| assert !image_files.include?("#{@tmpdir1}/foo.#{type}"), "foo.#{type} is included" }
  end
end
