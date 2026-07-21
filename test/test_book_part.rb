# frozen_string_literal: true

require_relative 'book_test_helper'
class PartTest < Test::Unit::TestCase
  include BookTestHelper

  def test_initialize
    book = Book::Base.new
    part = Book::Part.new(book, nil, nil)
    assert_equal nil, part.number
    assert_equal nil, part.chapters
    assert_equal '', part.name

    part = Book::Part.new(book, 123, [], 'name')
    assert_equal 123, part.number
    assert_equal [], part.chapters
    assert_equal 'name', part.name
  end

  # A part's .re is resolved against the book's directory, not the process's working directory.
  def test_content_is_read_relative_to_the_book_not_the_working_directory
    Dir.mktmpdir do |bookdir|
      File.write(File.join(bookdir, 'part1.re'), "= Part Title\n\nThe part body.\n")

      Dir.mktmpdir do |elsewhere|
        Dir.chdir(elsewhere) do
          book = Book::Base.new(bookdir)
          part = Book::Part.new(book, 1, [], 'part1.re')

          assert_equal "= Part Title\n\nThe part body.\n", part.content
          assert_equal 'part1', part.name
        end
      end
    end
  end

  # The same path is used to measure the part, so it moves with the content.
  def test_volume_is_measured_relative_to_the_book
    Dir.mktmpdir do |bookdir|
      File.write(File.join(bookdir, 'part1.re'), "= Part Title\n")

      Dir.mktmpdir do |elsewhere|
        Dir.chdir(elsewhere) do
          book = Book::Base.new(bookdir)
          part = Book::Part.new(book, 1, [], 'part1.re')

          assert_operator(part.volume.bytes, :>, 0)
        end
      end
    end
  end

  # With contentdir set, the .re lives under it, still inside the book.
  def test_content_honours_contentdir
    Dir.mktmpdir do |bookdir|
      FileUtils.mkdir_p(File.join(bookdir, 'contents'))
      File.write(File.join(bookdir, 'contents', 'part1.re'), "= In contentdir\n")

      Dir.mktmpdir do |elsewhere|
        Dir.chdir(elsewhere) do
          config = ReVIEW::Configure.values
          config['contentdir'] = 'contents'
          book = Book::Base.new(bookdir, config: config)
          part = Book::Part.new(book, 1, [], 'part1.re')

          assert_equal "= In contentdir\n", part.content
        end
      end
    end
  end

  def test_each_chapter
    part = Book::Part.new(nil, nil, [1, 2, 3])

    tmp = []
    part.each_chapter { |ch| tmp << ch }
    assert_equal [1, 2, 3], tmp
  end

  def test_volume
    book = Book::Base.new
    part = Book::Part.new(book, nil, [])
    assert part.volume
    assert_equal 0, part.volume.bytes
    assert_equal 0, part.volume.chars
    assert_equal 0, part.volume.lines

    chs = []
    tfs = [] ## prevent from removing Tempfile
    Tempfile.open('part_test') do |o|
      o.print '12345'
      chs << Book::Chapter.new(book, nil, nil, o.path)
      tfs << o
    end
    Tempfile.open('part_test') do |o|
      o.print '67890'
      chs << Book::Chapter.new(book, nil, nil, o.path)
      tfs << o
    end

    part = Book::Part.new(book, nil, chs)
    assert part.volume
    assert part.volume.bytes == 0
    assert part.volume.chars == 0
    assert part.volume.lines == 0
  end
end
