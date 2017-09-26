require 'book_test_helper'

class BookTest < Test::Unit::TestCase
  include BookTestHelper

  def assert_same_path(expected, result, *options)
    require 'pathname'
    ex_path = Pathname(expected).realpath
    re_path = Pathname(result).realpath
    assert_equal ex_path, re_path, *options
  end

  def test_s_update_rubyenv
    save_load_path = $LOAD_PATH.dup

    Dir.mktmpdir do |dir|
      Book.update_rubyenv(dir)
      assert_equal save_load_path, $LOAD_PATH
    end

    Dir.mktmpdir do |dir|
      local_lib_path = File.join(dir, 'lib')
      Dir.mkdir(local_lib_path)
      Book.update_rubyenv(dir)
      assert_equal save_load_path, $LOAD_PATH
    end

    num = rand(99999)
    test_const = "ReVIEW__BOOK__TEST__#{num}"
    begin
      Dir.mktmpdir do |dir|
        File.open(File.join(dir, 'review-ext.rb'), 'w') { |o| o.puts "#{test_const} = #{num}" }
        Book.update_rubyenv(dir)
        assert_equal num, (Object.class_eval { const_get(test_const) })
      end
    ensure
      Object.class_eval { remove_const(test_const) }
    end
  end

  def test_ext
    book = Book::Base.new(File.dirname(__FILE__))
    assert_equal '.re', book.ext
  end

  def test_read_chaps
    Dir.mktmpdir do |dir|
      book = Book::Base.new(dir)
      assert_equal '', book.read_chaps

      chaps_path = File.join(dir, 'CHAPS')
      re1_path = File.join(dir, "123#{book.ext}")
      re2_path = File.join(dir, "456#{book.ext}")

      File.open(chaps_path, 'w') { |o| o.print "abc\n" }
      File.open(re1_path, 'w') { |o| o.print "123\n" }
      File.open(re2_path, 'w') { |o| o.print "456\n" }

      assert_equal "abc\n", book.read_chaps

      File.unlink(chaps_path)
      assert_equal "#{re1_path}\n#{re2_path}", book.read_chaps

      File.unlink(re1_path)
      assert_equal re2_path, book.read_chaps

      File.unlink(re2_path)
      assert_equal '', book.read_chaps
    end
  end

  def test_read_part
    Dir.mktmpdir do |dir|
      book = Book::Base.new(dir)
      assert !book.part_exist?
      assert_raises Errno::ENOENT do # XXX: OK?
        book.read_part
      end

      chaps_path = File.join(dir, 'PART')
      chaps_content = "abc\n"
      File.open(chaps_path, 'w') { |o| o.print chaps_content }

      assert book.part_exist?
      assert_equal chaps_content, book.read_part

      File.open(chaps_path, 'w') { |o| o.print "XYZ\n" }
      assert_equal chaps_content, book.read_part
    end
  end

  def test_read_appendix
    Dir.mktmpdir do |dir|
      book = Book::Base.new(dir)
      assert_equal '', book.read_appendix

      post_path = File.join(dir, 'POSTDEF')
      re1_path = File.join(dir, "123#{book.ext}")
      re2_path = File.join(dir, "456#{book.ext}")

      File.open(post_path, 'w') { |o| o.print "abc\n" }
      File.open(re1_path, 'w') { |o| o.print "123\n" }
      File.open(re2_path, 'w') { |o| o.print "456\n" }

      assert_equal "abc\n", book.read_appendix

      File.unlink(post_path)
      assert_equal "#{re1_path}\n#{re2_path}", book.read_appendix

      File.unlink(re1_path)
      assert_equal re2_path, book.read_appendix

      File.unlink(re2_path)
      assert_equal '', book.read_appendix
    end
  end

  def test_read_postdef
    Dir.mktmpdir do |dir|
      book = Book::Base.new(dir)
      assert_equal '', book.read_postdef

      post_path = File.join(dir, 'POSTDEF')
      re1_path = File.join(dir, "123#{book.ext}")
      re2_path = File.join(dir, "456#{book.ext}")

      File.open(post_path, 'w') { |o| o.print "abc\n" }
      File.open(re1_path, 'w') { |o| o.print "123\n" }
      File.open(re2_path, 'w') { |o| o.print "456\n" }

      assert_equal '', book.read_postdef

      File.unlink(post_path)
      assert_equal '', book.read_postdef
    end
  end

  def test_read_bib
    Dir.mktmpdir do |dir|
      book = Book::Base.new(dir)
      assert !book.bib_exist?
      assert_raises Errno::ENOENT do # XXX: OK?
        book.read_bib
      end
      bib_path = File.join(dir, "bib#{book.ext}")
      File.open(bib_path, 'w') { |o| o.print "abc\n" }

      assert book.bib_exist?
      assert_equal "abc\n", book.read_bib
    end
  end

  # backward compatible
  def test_set_parameter
    book = Book::Base.new(File.dirname(__FILE__))
    book.config = :test
    assert_equal :test, book.config
  end

  def test_set_config
    book = Book::Base.new(File.dirname(__FILE__))
    book.config = :test
    assert_equal :test, book.config
  end

  def test_parse_chapters
    mktmpbookdir 'CHAPS' => '' do |_dir, book, _files|
      parts = book.instance_eval { parse_chapters }
      assert_equal 0, parts.size
    end

    mktmpbookdir 'CHAPS' => "chapter1.re\nchapter2\n" do |dir, book, _files|
      parts = book.instance_eval { parse_chapters }
      assert_equal 1, parts.size

      assert_equal nil, parts[0].number
      assert_equal 2, parts[0].chapters.size
      chaps = parts[0].chapters.map { |ch| [ch.number, ch.name, ch.path] }
      expect = [
        [1, 'chapter1', File.join(dir, 'chapter1.re')],
        [2, 'chapter2', File.join(dir, 'chapter2')]
      ]
      assert_equal expect, chaps
    end

    mktmpbookdir 'CHAPS' => <<EOC do |dir, book, _files|
part1_chapter1.re
part1_chapter2.re


part2_chapter1.re
part2_chapter2.re
part2_chapter3.re

part3_chapter1.re
EOC
      parts = book.instance_eval { parse_chapters }
      assert_equal 3, parts.size

      assert_equal nil, parts[0].number
      assert_equal 2, parts[0].chapters.size
      chaps = parts[0].chapters.map { |ch| [ch.number, ch.name, ch.path] }
      expect = [
        [1, 'part1_chapter1', File.join(dir, 'part1_chapter1.re')],
        [2, 'part1_chapter2', File.join(dir, 'part1_chapter2.re')]
      ]
      assert_equal expect, chaps

      assert_equal nil, parts[1].number
      assert_equal 3, parts[1].chapters.size
      chaps = parts[1].chapters.map { |ch| [ch.number, ch.name, ch.path] }
      expect = [
        [3, 'part2_chapter1', File.join(dir, 'part2_chapter1.re')],
        [4, 'part2_chapter2', File.join(dir, 'part2_chapter2.re')],
        [5, 'part2_chapter3', File.join(dir, 'part2_chapter3.re')]
      ]
      assert_equal expect, chaps

      assert_equal nil, parts[2].number
      assert_equal 1, parts[2].chapters.size
      chaps = parts[2].chapters.map { |ch| [ch.number, ch.name, ch.path] }
      expect = [
        [6, 'part3_chapter1', File.join(dir, 'part3_chapter1.re')]
      ]
      assert_equal expect, chaps
    end
  end

  def test_parse_chpaters_with_parts_file
    n_test = 0
    [
      [
        # 期待されるパートの数, :chapter_fileの内容, :part_fileの内容, 期待されるパートタイトルのリスト
        2,
        "part1_chapter1.re\n\npart2_chpater1.re\n",
        "part1\npart2\npart3\n",
        %w[part1 part2]
      ],
      [
        3,
        "part1_chapter1.re\n\npart2_chapter1.re\n\npart3_chapter1.re",
        "part1\n",
        [
          'part1',
          '', # XXX: OK?
          ''
        ]
      ],
      [
        1,
        "part1_chapter1.re\n",
        '',
        [
          '', # XXX: OK?
        ]
      ],
      [
        1,
        "part1_chapter1.re\n",
        nil,
        [
          ''
        ]
      ]
    ].each do |n_parts, chaps_text, parts_text, part_names|
      n_test += 1
      Dir.mktmpdir do |dir|
        book = Book::Base.new(dir)
        chaps_path = File.join(dir, 'CHAPS')
        File.open(chaps_path, 'w') { |o| o.print chaps_text }
        if parts_text
          parts_path = File.join(dir, 'PART')
          File.open(parts_path, 'w') { |o| o.print parts_text }
        end

        parts = book.instance_eval { parse_chapters }
        assert_equal n_parts, parts.size, "##{n_test}"
        assert_equal part_names, parts.map(&:name), "##{n_test}"
      end
    end
  end

  def test_prefaces
    mktmpbookdir do |_dir, book, _files|
      assert_equal nil, book.prefaces
    end

    mktmpbookdir 'PREDEF' => '' do |_dir, book, _files|
      assert_equal nil, book.prefaces # XXX: OK?
    end

    mktmpbookdir 'PREDEF' => 'chapter1',
                 'chapter1.re' => '' do |_dir, book, files|
      assert_kind_of Book::Part, book.prefaces
      assert_equal '', book.prefaces.name
      assert_equal 1, book.prefaces.chapters.size
      assert_equal 'chapter1', book.prefaces.chapters.first.name
      assert_equal files['chapter1.re'], book.prefaces.chapters.first.path
    end

    mktmpbookdir 'PREDEF' => "chapter1\n\nchapter2",
                 'chapter1.re' => '', 'chapter2.re' => '' do |_dir, book, files|
      assert_kind_of Book::Part, book.prefaces
      assert_equal '', book.prefaces.name
      assert_equal 2, book.prefaces.chapters.size
      assert_equal 'chapter1', book.prefaces.chapters.first.name
      assert_equal files['chapter1.re'], book.prefaces.chapters.first.path
      assert_equal 'chapter2', book.prefaces.chapters.last.name
      assert_equal files['chapter2.re'], book.prefaces.chapters.last.path
    end

    mktmpbookdir 'PREDEF' => 'chapter1 chapter2',
                 'chapter1.re' => '', 'chapter2.re' => '' do |_dir, book, _files|
      assert_kind_of Book::Part, book.prefaces
      assert_equal '', book.prefaces.name
      assert_equal 2, book.prefaces.chapters.size # XXX: OK?
    end

    mktmpbookdir 'PREDEF' => 'not_exist' do |_dir, book, _files|
      assert_raises FileNotFound do
        assert_equal nil, book.prefaces
      end
    end

    mktmpbookdir 'PREDEF' => 'chapter1.re',
                 'chapter1.re' => '' do |_dir, book, _files|
      assert_kind_of Book::Part, book.prefaces
      assert_equal '', book.prefaces.name
      assert_equal 1, book.prefaces.chapters.size
    end

    mktmpbookdir 'PREDEF' => 'chapter1.txt',
                 'chapter1.txt' => '' do |_dir, book, _files|
      assert_kind_of Book::Part, book.prefaces
      assert_equal '', book.prefaces.name
      assert_equal 1, book.prefaces.chapters.size
    end
  end

  def test_appendix
    mktmpbookdir do |_dir, book, _files|
      assert_equal nil, book.appendix
    end

    mktmpbookdir 'POSTDEF' => '' do |_dir, book, _files|
      assert_equal nil, book.appendix
    end

    mktmpbookdir 'POSTDEF' => 'chapter1',
                 'chapter1.re' => '' do |_dir, book, files|
      assert_kind_of Book::Part, book.appendix
      assert_equal '', book.appendix.name
      assert_equal 1, book.appendix.chapters.size
      assert_equal 'chapter1', book.appendix.chapters.first.name
      assert_equal files['chapter1.re'], book.appendix.chapters.first.path
      assert_equal 1, book.appendix.chapters.first.number
    end

    mktmpbookdir 'POSTDEF' => "chapter1\n\nchapter2",
                 'chapter1.re' => '', 'chapter2.re' => '' do |_dir, book, files|
      assert_kind_of Book::Part, book.appendix
      assert_equal '', book.appendix.name
      assert_equal 2, book.appendix.chapters.size
      assert_equal 'chapter1', book.appendix.chapters.first.name
      assert_equal files['chapter1.re'], book.appendix.chapters.first.path
      assert_equal 'chapter2', book.appendix.chapters.last.name
      assert_equal files['chapter2.re'], book.appendix.chapters.last.path
      assert_equal 1, book.appendix.chapters.first.number
      assert_equal 2, book.appendix.chapters.last.number
    end

    mktmpbookdir 'POSTDEF' => 'chapter1 chapter2',
                 'chapter1.re' => '', 'chapter2.re' => '' do |_dir, book, _files|
      assert_kind_of Book::Part, book.appendix
      assert_equal '', book.appendix.name
      assert_equal 2, book.appendix.chapters.size # XXX: OK?
      assert_equal 1, book.appendix.chapters.first.number
      assert_equal 2, book.appendix.chapters.last.number
    end

    mktmpbookdir 'POSTDEF' => 'not_exist' do |_dir, book, _files|
      assert_raises FileNotFound do
        assert_equal nil, book.appendix
      end
    end

    mktmpbookdir 'catalog.yml' => "APPENDIX:\n  - p01.re",
                 'p01.re' => '= appendix' do |_dir, book, _files|
      assert_equal 'appendix', book.appendix.chapters.first.title
      assert_equal 1, book.appendix.chapters.first.number
    end
  end

  def test_postscripts
    mktmpbookdir 'catalog.yml' => "POSTDEF:\n  - b01.re",
                 'b01.re' => '= back' do |_dir, book, _files|
      assert_kind_of Book::Part, book.postscripts
      assert_equal 1, book.postscripts.chapters.size
      assert_equal 'back', book.postscripts.chapters.first.title
      assert_equal nil, book.postscripts.chapters.first.number
    end
  end

  def test_parts
    mktmpbookdir do |_dir, book, _files|
      assert book.parts.empty?
      assert !book.part(0)
      assert !book.part(1)

      tmp = []
      book.each_part { tmp << true }
      assert tmp.empty?
    end

    mktmpbookdir 'CHAPS' => "ch1\nch2\n\nch3", 'PART' => "foo\nbar\n" do |_dir, book, _files|
      parts = book.parts
      assert_equal 2, parts.size
      assert !book.part(0)
      assert_equal 'foo', book.part(1).name
      assert_equal 'bar', book.part(2).name
      assert !book.part(3)

      tmp = []
      book.each_part { |p| tmp << p.number }
      assert_equal [1, 2], tmp
    end
  end

  def test_chapters
    mktmpbookdir 'CHAPS' => "ch1\nch2\n\nch3" do |_dir, book, _files|
      chapters = book.chapters
      assert_equal 3, chapters.size

      ch_names = %w[ch1 ch2 ch3]
      tmp = []
      book.each_chapter { |ch| tmp << ch.name }
      assert_equal ch_names, tmp

      ch_names.each do |name|
        assert book.chapter(name)
        assert_equal name, book.chapter(name).name
      end

      assert_raises ReVIEW::KeyError do
        book.chapter('not exist')
      end
    end

    mktmpbookdir 'CHAPS' => "ch1.txt\nch2.txt\n\nch3.txt" do |_dir, book, _files|
      chapters = book.chapters
      assert_equal 3, chapters.size

      ch_names = %w[ch1 ch2 ch3]
      tmp = []
      book.each_chapter { |ch| tmp << ch.name }
      assert_equal ch_names, tmp

      ch_names.each do |name|
        assert book.chapter(name)
        assert_equal name, book.chapter(name).name
      end

      assert_raises ReVIEW::KeyError do
        book.chapter('not exist')
      end
    end
  end

  def test_next_chapter
    mktmpbookdir 'CHAPS' => "ch1\nch2" do |_dir, book, _files|
      chapter = book.chapter('ch1')
      assert_equal book.chapter('ch2'), book.next_chapter(chapter)

      chapter = book.chapter('ch2')
      assert_equal nil, book.next_chapter(chapter)
    end
  end

  def test_prev_chapter
    mktmpbookdir 'CHAPS' => "ch1\nch2" do |_dir, book, _files|
      chapter = book.chapter('ch2')
      assert_equal book.chapter('ch1'), book.prev_chapter(chapter)

      chapter = book.chapter('ch1')
      assert_equal nil, book.prev_chapter(chapter)
    end
  end

  def test_volume
    mktmpbookdir do |_dir, book, _files|
      assert book.volume
      assert_equal 0, book.volume.bytes
      assert_equal 0, book.volume.chars
      assert_equal 0, book.volume.lines
    end

    mktmpbookdir 'CHAPS' => 'chapter1.re', 'chapter1.re' => '12345' do |_dir, book, _files|
      assert book.volume
      assert book.volume.bytes > 0
      assert book.volume.chars > 0
      assert book.volume.lines > 0
    end

    mktmpbookdir 'preface.re' => '12345' do |dir, _book, _files|
      Dir.chdir(dir) do
        book2 = Book::Base.new('.')
        assert book2.volume
        assert book2.volume.bytes > 0
        assert book2.volume.chars > 0
        assert book2.volume.lines > 0
      end
    end
  end

  def test_basedir
    Dir.mktmpdir do |dir|
      book = Book::Base.new(dir)
      assert_equal dir, book.basedir
    end
  end

  def test_page_metric
    Dir.mktmpdir do |dir|
      book = Book::Base.new(dir)
      assert_equal ReVIEW::Book::PageMetric::A5, book.page_metric
    end
  end

  def test_page_metric_config
    mktmpbookdir('config.yml' => "bookname: book\npage_metric: B5\n") do |dir, _book, _files|
      book = Book::Base.new(dir)
      config_file = File.join(dir, 'config.yml')
      book.load_config(config_file)
      assert_equal ReVIEW::Book::PageMetric::B5, book.page_metric
    end
  end

  def test_page_metric_config_array
    mktmpbookdir('config.yml' => "bookname: book\npage_metric: [46, 80, 30, 74, 2]\n") do |dir, _book, _files|
      book = Book::Base.new(dir)
      config_file = File.join(dir, 'config.yml')
      book.load_config(config_file)
      assert_equal ReVIEW::Book::PageMetric::B5, book.page_metric
    end
  end
end
