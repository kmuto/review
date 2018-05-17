require 'test_helper'
require 'review'
require 'review/book/image_finder'
require 'fileutils'

class ImageFinderTest < Test::Unit::TestCase
  include ReVIEW

  def setup
  end

  def test_find_path_pattern1
    dir = Dir.mktmpdir
    begin
      path = dir + '/builder/ch01/foo.jpg'
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.touch(path)

      finder = ReVIEW::Book::ImageFinder.new(dir, 'ch01', 'builder', ['.jpg'])
      assert_equal(path, finder.find_path('foo'))
    ensure
      FileUtils.remove_entry_secure dir
    end
  end

  def test_find_path_pattern2
    dir = Dir.mktmpdir
    begin
      path = dir + '/builder/ch01-foo.jpg'
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.touch(path)

      finder = ReVIEW::Book::ImageFinder.new(dir, 'ch01', 'builder', ['.jpg'])
      assert_equal(path, finder.find_path('foo'))
    ensure
      FileUtils.remove_entry_secure dir
    end
  end

  def test_find_path_pattern3
    dir = Dir.mktmpdir
    begin
      path = dir + '/builder/foo.jpg'
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.touch(path)

      finder = ReVIEW::Book::ImageFinder.new(dir, 'ch01', 'builder', ['.jpg'])
      assert_equal(path, finder.find_path('foo'))
    ensure
      FileUtils.remove_entry_secure dir
    end
  end

  def test_find_path_pattern4
    dir = Dir.mktmpdir
    begin
      path = dir + '/ch01/foo.jpg'
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.touch(path)

      finder = ReVIEW::Book::ImageFinder.new(dir, 'ch01', 'builder', ['.jpg'])
      assert_equal(path, finder.find_path('foo'))
    ensure
      FileUtils.remove_entry_secure dir
    end
  end

  def test_find_path_pattern5
    dir = Dir.mktmpdir
    begin
      path = dir + '/ch01-foo.jpg'
      FileUtils.mkdir_p(File.dirname(path))
      FileUtils.touch(path)

      finder = ReVIEW::Book::ImageFinder.new(dir, 'ch01', 'builder', ['.jpg'])
      assert_equal(path, finder.find_path('foo'))
    ensure
      FileUtils.remove_entry_secure dir
    end
  end

  def test_find_path_dir_symlink
    dir = Dir.mktmpdir
    begin
      path_src = dir + '/src'
      path_dst = dir + '/ch01'
      FileUtils.mkdir_p(path_src)
      FileUtils.symlink(path_src, path_dst)
      path_srcimg = path_src + '/foo.jpg'
      path_dstimg = path_dst + '/foo.jpg'
      FileUtils.touch(path_srcimg)

      finder = ReVIEW::Book::ImageFinder.new(dir, 'ch01', 'builder', ['.jpg'])
      assert_equal(path_dstimg, finder.find_path('foo'))
    ensure
      FileUtils.remove_entry_secure dir
    end
  end

  def test_find_path_caseinsensitive
    if /mswin|mingw|cygwin/ !~ RUBY_PLATFORM
      dir = Dir.mktmpdir
      begin
        path = File.join(dir, 'ch01-foo.jpg')
        FileUtils.touch(path)
        path = File.join(dir, 'ch01-Foo.png')
        FileUtils.touch(path)
        finder = ReVIEW::Book::ImageFinder.new(dir, 'ch01', 'builder', ['.jpg'])
        assert_equal(File.join(dir, 'ch01-foo.jpg'), finder.find_path('foo'))

        %w[JPG Jpg JPg jPG].each do |ext|
          path = File.join(dir, "ch01-foo.#{ext}")
          FileUtils.touch(path)
        end

        finder = ReVIEW::Book::ImageFinder.new(dir, 'ch01', 'builder', ['.jpg'])
        assert_equal(File.join(dir, 'ch01-foo.JPG'), finder.find_path('foo'))
      ensure
        FileUtils.remove_entry_secure dir
      end
    end
  end
end
