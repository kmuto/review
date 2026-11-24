# frozen_string_literal: true

require_relative 'test_helper'
require 'review'
require 'review/book/image_finder'
require 'fileutils'

class ImageFinderTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    if ENV['GITHUB_WORKSPACE']
      ENV['TMPDIR'] = File.join(ENV['GITHUB_WORKSPACE'], 'tmp_review')
      FileUtils.mkdir_p(ENV['TMPDIR'])
    end
    @dir = Dir.mktmpdir
    @book = Book::Base.new(@dir, config: { 'builder' => 'builder', 'imagedir' => @dir })
    @book.image_types = ['.jpg']
  end

  def teardown
    if @dir
      FileUtils.remove_entry_secure(@dir)
    end
  end

  def finder
    ch = Book::Chapter.new(@book, 1, 'ch01', nil)
    ReVIEW::Book::ImageFinder.new(ch)
  end

  def test_find_path_pattern1
    path = File.join(@dir, 'builder/ch01/foo.jpg')
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.touch(path)

    assert_equal(path, finder.find_path('foo'))
  end

  def test_find_path_pattern2
    path = File.join(@dir, 'builder/ch01-foo.jpg')
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.touch(path)

    assert_equal(path, finder.find_path('foo'))
  end

  def test_find_path_pattern3
    path = File.join(@dir, 'builder/foo.jpg')
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.touch(path)

    assert_equal(path, finder.find_path('foo'))
  end

  def test_find_path_pattern4
    path = File.join(@dir, 'ch01/foo.jpg')
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.touch(path)

    assert_equal(path, finder.find_path('foo'))
  end

  def test_find_path_pattern5
    path = File.join(@dir, 'ch01-foo.jpg')
    FileUtils.mkdir_p(File.dirname(path))
    FileUtils.touch(path)

    assert_equal(path, finder.find_path('foo'))
  end

  def test_find_path_dir_symlink
    path_src = File.join(@dir, 'src')
    path_dst = File.join(@dir, 'ch01')
    FileUtils.mkdir_p(path_src)
    FileUtils.symlink(path_src, path_dst)
    path_srcimg = File.join(path_src, 'foo.jpg')
    path_dstimg = File.join(path_dst, 'foo.jpg')
    FileUtils.touch(path_srcimg)

    assert_equal(path_dstimg, finder.find_path('foo'))
  end

  def test_entry_object
    assert_equal({ basename: 'ch01/Foo', downcase: 'ch01/Foo.jpg', path: 'ch01/Foo.JPG' },
                 finder.entry_object('ch01/Foo.JPG'))
  end

  def test_path_priority_before_extension_priority
    jpg = File.join(@dir, 'ch01-foo.JPG')
    png = File.join(@dir, 'ch01-foo.png')
    FileUtils.touch([jpg, png, File.join(@dir, 'foo.gif')])
    images = finder
    @book.image_types = %w[.gif .png .jpg]
    assert_equal(png, images.find_path('foo'))
    @book.image_types = %w[.gif .jpg .png]
    assert_equal(jpg, images.find_path('foo'))
    assert_nil(images.find_path('Foo'))
  end

  def test_added_image_is_local_to_finder
    original = File.join(@dir, 'foo.jpg')
    FileUtils.touch(original)
    images = finder
    assert_equal(original, images.find_path('foo'))

    generated = File.join(@dir, 'ch01-foo.jpg')
    FileUtils.touch(generated)
    images.add_entry(generated)
    assert_equal(generated, images.find_path('foo'))
    assert_equal([original, generated], images.add_entry(generated).map { |entry| entry[:path] })
    assert_equal(original, finder.find_path('foo'))

    @book.cache.reset
    assert_equal(generated, finder.find_path('foo'))
  end

  def test_adding_another_extension_is_local_to_finder
    jpg = File.join(@dir, 'foo.jpg')
    png = File.join(@dir, 'foo.png')
    FileUtils.touch(jpg)
    @book.image_types = %w[.png .jpg]
    images = finder
    other = finder
    assert_equal([jpg], images.add_entry(jpg).map { |entry| entry[:path] })

    FileUtils.touch(png)
    images.add_entry(png)
    assert_equal(png, images.find_path('foo'))
    assert_equal(jpg, other.find_path('foo'))
  end
end
