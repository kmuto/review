# frozen_string_literal: true

require 'test_helper'
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
  end

  def teardown
    if @dir
      FileUtils.remove_entry_secure(@dir)
    end
  end

  def finder
    book = Book::Base.new(@dir, config: { 'builder' => 'builder', 'imagedir' => @dir })
    book.image_types = ['.jpg']
    ch = Book::Chapter.new(book, 1, 'ch01', nil)
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
end
