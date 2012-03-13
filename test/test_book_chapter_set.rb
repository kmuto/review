require 'book_test_helper'
class ChapterSetTest < Test::Unit::TestCase
  include BookTestHelper

  def test_s_for_pathes
    dir_files = {
      'ch1.re' => 'ch1',
      'ch2.re' => 'ch2',
    }
    mktmpbookdir dir_files do |dir, book, files|
      paths = files.values.grep(/\.re\z/)
      cs = nil
      assert_nothing_raised do
        cs = Book::ChapterSet.for_pathes(paths)
      end
      assert_equal 2, cs.chapters.size
    end
  end

  def test_s_for_argv
    begin
      paths = []
      Book::ChapterSet.class_eval { const_set(:ARGV, paths) }

      dir_files = {
        'ch1.re' => 'ch1',
        'ch2.re' => 'ch2',
      }
      mktmpbookdir dir_files do |dir, book, files|
        paths.concat files.values.grep(/\.re\z/)
        cs = nil
        assert_nothing_raised do
          cs = Book::ChapterSet.for_argv
        end
        assert_equal 2, cs.chapters.size
        assert_equal ['ch1', 'ch2'], cs.chapters.map(&:name).sort
      end

    ensure
      Book::ChapterSet.class_eval { remove_const(:ARGV) }
      Book::ChapterSet.class_eval { const_set(:ARGV, []) }
    end

    begin
      $stdin = StringIO.new('abc')
      cs = nil
      assert_nothing_raised do
        cs = Book::ChapterSet.for_argv
      end
      assert_equal 1, cs.chapters.size
      assert_equal '-', cs.chapters.first.name

    ensure
      $stdin = STDIN
    end
  end

  def test_no_part?
    cs = Book::ChapterSet.new([])
    assert cs.no_part?

    ch = Book::Chapter.new(nil, nil, nil, nil, StringIO.new)
    cs = Book::ChapterSet.new([ch])
    assert cs.no_part?
  end

  def test_chapters
    ch1 = Book::Chapter.new(nil, 123, nil, nil, StringIO.new)
    ch2 = Book::Chapter.new(nil, 456, nil, nil, StringIO.new)
    cs = Book::ChapterSet.new([ch1, ch2])
    assert_equal [123, 456], cs.chapters.map(&:number)

    tmp = [ch1, ch2]
    cs.each_chapter do |ch|
      assert tmp.delete(ch)
    end
    assert tmp.empty?
  end

  def test_ext
    cs = Book::ChapterSet.new([])
    assert_equal '.re', cs.ext
  end
end
