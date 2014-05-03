# encoding: utf-8
require 'book_test_helper'

class BookTest < Test::Unit::TestCase
  include BookTestHelper

  def assert_same_path(expected, result, *options)
    require 'pathname'
    ex_path = Pathname(expected).realpath
    re_path = Pathname(result).realpath
    assert_equal ex_path, re_path, *options
  end

  def test_s_load_default
    Dir.mktmpdir do |dir|
      File.open(File.join(dir, 'CHAPS'), 'w') {}
      Dir.chdir(dir) do
        assert_same_path dir, File.expand_path(Book.load_default.basedir), "error in dir CHAPS"
      end

      subdir = File.join(dir, 'sub')
      Dir.mkdir(subdir)
      Dir.chdir(subdir) do
        assert_same_path dir, File.expand_path(Book.load_default.basedir), "error in dir sub"
      end

      sub2dir = File.join(dir, 'sub', 'sub')
      Dir.mkdir(sub2dir)
      Dir.chdir(sub2dir) do
        assert_same_path dir, File.expand_path(Book.load_default.basedir), "error in dir sub sub"
      end

      sub3dir = File.join(dir, 'sub', 'sub', 'sub')
      Dir.mkdir(sub3dir)
      Dir.chdir(sub3dir) do
        assert_same_path sub3dir, File.expand_path(Book.load_default.basedir), "error in dir sub sub sub"
      end
    end

    # tests for ReVIEW.book
    default_book = nil
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        default_book = ReVIEW.book
        assert default_book
      end
    end
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        assert_equal default_book, ReVIEW.book, "chdir mktmpdir"
      end
    end
  end

  def test_s_load
    Dir.mktmpdir do |dir|
      book = Book.load(dir)
      defs = get_instance_variables(Book::Parameters.default)
      pars = get_instance_variables(book.instance_eval { @parameters })
      assert_equal defs, pars
    end
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

    begin
      Dir.mktmpdir do |dir|
        local_lib_path = File.join(dir, 'lib')
        Dir.mkdir(local_lib_path)
        Dir.mkdir(File.join(local_lib_path, 'review'))
        Book.update_rubyenv(dir)
        assert save_load_path != $LOAD_PATH
        assert $LOAD_PATH.index(local_lib_path)
      end
    ensure
      $LOAD_PATH.replace save_load_path
    end

    num = rand(99999)
    test_const = "ReVIEW__BOOK__TEST__#{num}"
    begin
      Dir.mktmpdir do |dir|
        File.open(File.join(dir, 'review-ext.rb'), 'w') do |o|
          o.puts "#{test_const} = #{num}"
        end
        Book.update_rubyenv(dir)
        assert_equal num, Object.class_eval { const_get(test_const) }
      end
    ensure
      Object.class_eval { remove_const(test_const) }
    end
  end

  def test_ext
    book = Book::Base.new(File.dirname(__FILE__))
    assert_equal '.re', book.ext
  end

  def test_read_CHAPS
    Dir.mktmpdir do |dir|
      book = Book::Base.new(dir)
      assert_equal "", book.read_CHAPS

      chaps_path = File.join(dir, 'CHAPS')
      re1_path = File.join(dir, "123#{book.ext}")
      re2_path = File.join(dir, "456#{book.ext}")

      File.open(chaps_path, 'w') {|o| o.print "abc\n" }
      File.open(re1_path, 'w') {|o| o.print "123\n" }
      File.open(re2_path, 'w') {|o| o.print "456\n" }

      assert_equal "abc\n", book.read_CHAPS

      File.unlink(chaps_path)
      assert_equal "#{re1_path}\n#{re2_path}", book.read_CHAPS

      File.unlink(re1_path)
      assert_equal "#{re2_path}", book.read_CHAPS

      File.unlink(re2_path)
      assert_equal "", book.read_CHAPS
    end
  end

  def test_read_PART
    Dir.mktmpdir do |dir|
      book = Book::Base.new(dir)
      assert !book.part_exist?
      assert_raises Errno::ENOENT do # XXX: OK?
        book.read_PART
      end

      chaps_path = File.join(dir, 'PART')
      chaps_content = "abc\n"
      File.open(chaps_path, 'w') {|o| o.print chaps_content }

      assert book.part_exist?
      assert_equal chaps_content, book.read_PART

      File.open(chaps_path, 'w') {|o| o.print "XYZ\n" }
      assert_equal chaps_content, book.read_PART
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
      File.open(bib_path, 'w') {|o| o.print "abc\n" }

      assert book.bib_exist?
      assert_equal "abc\n", book.read_bib
    end
  end

  def test_setParameter
    book = Book::Base.new(File.dirname(__FILE__))
    book.param = :test
    assert_equal :test, book.instance_eval {@param}
  end

  def test_parse_chapters
    mktmpbookdir 'CHAPS' => '' do |dir, book, files|
      parts = book.instance_eval { parse_chapters }
      assert_equal 0, parts.size
    end

    mktmpbookdir 'CHAPS' => "chapter1.re\nchapter2\n" do |dir, book, files|
      parts = book.instance_eval { parse_chapters }
      assert_equal 1, parts.size

      assert_equal 1, parts[0].number
      assert_equal 2, parts[0].chapters.size
      chaps = parts[0].chapters.map {|ch| [ch.number, ch.name, ch.path] }
      expect = [
        [1, 'chapter1', File.join(dir, 'chapter1.re')],
        [2, 'chapter2', File.join(dir, 'chapter2')],
      ]
      assert_equal expect, chaps
    end

    mktmpbookdir 'CHAPS' => <<EOC do |dir, book, files|
part1_chapter1.re
part1_chapter2.re


part2_chapter1.re
part2_chapter2.re
part2_chapter3.re

part3_chapter1.re
EOC
      parts = book.instance_eval { parse_chapters }
      assert_equal 3, parts.size

      assert_equal 1, parts[0].number
      assert_equal 2, parts[0].chapters.size
      chaps = parts[0].chapters.map {|ch| [ch.number, ch.name, ch.path] }
      expect = [
        [1, 'part1_chapter1', File.join(dir, 'part1_chapter1.re')],
        [2, 'part1_chapter2', File.join(dir, 'part1_chapter2.re')],
      ]
      assert_equal expect, chaps

      assert_equal 2, parts[1].number
      assert_equal 3, parts[1].chapters.size
      chaps = parts[1].chapters.map {|ch| [ch.number, ch.name, ch.path] }
      expect = [
        [3, 'part2_chapter1', File.join(dir, 'part2_chapter1.re')],
        [4, 'part2_chapter2', File.join(dir, 'part2_chapter2.re')],
        [5, 'part2_chapter3', File.join(dir, 'part2_chapter3.re')],
      ]
      assert_equal expect, chaps

      assert_equal 3, parts[2].number
      assert_equal 1, parts[2].chapters.size
      chaps = parts[2].chapters.map {|ch| [ch.number, ch.name, ch.path] }
      expect = [
        [6, 'part3_chapter1', File.join(dir, 'part3_chapter1.re')],
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
        %w(part1 part2),
      ],
      [
        3,
        "part1_chapter1.re\n\npart2_chapter1.re\n\npart3_chapter1.re",
        "part1\n",
        [
          "part1",
          nil, # XXX: OK?
          ""
        ],
      ],
      [
        1,
        "part1_chapter1.re\n",
        "",
        [
          nil, # XXX: OK?
        ],
      ],
      [
        1,
        "part1_chapter1.re\n",
        nil,
        [
          "",
        ],
      ],
    ].each do |n_parts, chaps_text, parts_text, part_names|
      n_test += 1
      Dir.mktmpdir do |dir|
        params = Book::Parameters.new(:part_file => 'PARTS')
        book = Book::Base.new(dir, params)
        chaps_path = File.join(dir, 'CHAPS')
        File.open(chaps_path, 'w') {|o| o.print chaps_text }
        unless parts_text.nil?
          parts_path = File.join(dir, 'PARTS')
          File.open(parts_path, 'w') {|o| o.print parts_text }
        end

        parts = book.instance_eval { parse_chapters }
        assert_equal n_parts, parts.size, "\##{n_test}"
        assert_equal part_names, parts.map {|p| p.name }, "\##{n_test}"
      end
    end
  end

  def test_prefaces
    mktmpbookdir do |dir, book, files|
      assert_equal nil, book.prefaces
    end

    mktmpbookdir 'preface.re' => '' do |dir, book, files|
      assert_kind_of Book::Part, book.prefaces
      assert_equal '', book.prefaces.name
      assert_equal 1, book.prefaces.chapters.size
      assert_equal "preface", book.prefaces.chapters.first.name
      assert_equal files['preface.re'], book.prefaces.chapters.first.path
      assert_equal nil, book.prefaces.chapters.first.number
    end

    mktmpbookdir 'preface.re' => '',
                 'PREDEF' => '' do |dir, book, files|
      assert_equal nil, book.prefaces # XXX: OK?
    end

    mktmpbookdir 'PREDEF' => '' do |dir, book, files|
      assert_equal nil, book.prefaces
    end

    mktmpbookdir 'PREDEF' => 'chapter1',
                 'chapter1.re' => '' do |dir, book, files|
      assert_kind_of Book::Part, book.prefaces
      assert_equal '', book.prefaces.name
      assert_equal 1, book.prefaces.chapters.size
      assert_equal "chapter1", book.prefaces.chapters.first.name
      assert_equal files['chapter1.re'], book.prefaces.chapters.first.path
    end

    mktmpbookdir 'PREDEF' => "chapter1\n\nchapter2",
                 'chapter1.re' => '', 'chapter2.re' => '' do |dir, book, files|
      assert_kind_of Book::Part, book.prefaces
      assert_equal '', book.prefaces.name
      assert_equal 2, book.prefaces.chapters.size
      assert_equal "chapter1", book.prefaces.chapters.first.name
      assert_equal files['chapter1.re'], book.prefaces.chapters.first.path
      assert_equal "chapter2", book.prefaces.chapters.last.name
      assert_equal files['chapter2.re'], book.prefaces.chapters.last.path
    end

    mktmpbookdir 'PREDEF' => "chapter1 chapter2",
                 'chapter1.re' => '', 'chapter2.re' => '' do |dir, book, files|
      assert_kind_of Book::Part, book.prefaces
      assert_equal '', book.prefaces.name
      assert_equal 2, book.prefaces.chapters.size # XXX: OK?
    end

    mktmpbookdir 'PREDEF' => 'not_exist' do |dir, book, files|
      assert_raises FileNotFound do
        assert_equal nil, book.prefaces
      end
    end

    mktmpbookdir 'PREDEF' => 'chapter1.re',
                 'chapter1.re' => '' do |dir, book, files|
      assert_kind_of Book::Part, book.prefaces
      assert_equal '', book.prefaces.name
      assert_equal 1, book.prefaces.chapters.size
    end

    mktmpbookdir 'PREDEF' => 'chapter1.txt',
                 'chapter1.txt' => '' do |dir, book, files|
      assert_kind_of Book::Part, book.prefaces
      assert_equal '', book.prefaces.name
      assert_equal 1, book.prefaces.chapters.size
    end
  end

  def test_postscripts
    mktmpbookdir do |dir, book, files|
      assert_equal nil, book.postscripts
    end

    mktmpbookdir 'appendix.re' => '' do |dir, book, files|
      assert_kind_of Book::Part, book.postscripts
      assert_equal '', book.postscripts.name
      assert_equal 1, book.postscripts.chapters.size
      assert_equal "appendix", book.postscripts.chapters.first.name
      assert_equal files['appendix.re'], book.postscripts.chapters.first.path
      assert_equal nil, book.postscripts.chapters.first.number
    end

    mktmpbookdir 'postscript.re' => '' do |dir, book, files|
      assert_kind_of Book::Part, book.postscripts
      assert_equal '', book.postscripts.name
      assert_equal 1, book.postscripts.chapters.size
      assert_equal "postscript", book.postscripts.chapters.first.name
      assert_equal files['postscript.re'], book.postscripts.chapters.first.path
      assert_equal nil, book.postscripts.chapters.first.number
    end

    mktmpbookdir 'appendix.re' => '',
                 'postscript.re' => '' do |dir, book, files|
      assert_kind_of Book::Part, book.postscripts
      assert_equal '', book.postscripts.name
      assert_equal 2, book.postscripts.chapters.size
      assert_equal "appendix", book.postscripts.chapters.first.name
      assert_equal files['appendix.re'], book.postscripts.chapters.first.path
      assert_equal nil, book.postscripts.chapters.first.number
      assert_equal "postscript", book.postscripts.chapters.last.name
      assert_equal files['postscript.re'], book.postscripts.chapters.last.path
      assert_equal nil, book.postscripts.chapters.last.number
    end

    mktmpbookdir 'preface.re' => '',
                 'POSTDEF' => '' do |dir, book, files|
      assert_equal nil, book.postscripts # XXX: OK?
    end

    mktmpbookdir 'POSTDEF' => '' do |dir, book, files|
      assert_equal nil, book.postscripts
    end

    mktmpbookdir 'POSTDEF' => 'chapter1',
                 'chapter1.re' => '' do |dir, book, files|
      assert_kind_of Book::Part, book.postscripts
      assert_equal '', book.postscripts.name
      assert_equal 1, book.postscripts.chapters.size
      assert_equal "chapter1", book.postscripts.chapters.first.name
      assert_equal files['chapter1.re'], book.postscripts.chapters.first.path
    end

    mktmpbookdir 'POSTDEF' => "chapter1\n\nchapter2",
                 'chapter1.re' => '', 'chapter2.re' => '' do |dir, book, files|
      assert_kind_of Book::Part, book.postscripts
      assert_equal '', book.postscripts.name
      assert_equal 2, book.postscripts.chapters.size
      assert_equal "chapter1", book.postscripts.chapters.first.name
      assert_equal files['chapter1.re'], book.postscripts.chapters.first.path
      assert_equal "chapter2", book.postscripts.chapters.last.name
      assert_equal files['chapter2.re'], book.postscripts.chapters.last.path
    end

    mktmpbookdir 'POSTDEF' => "chapter1 chapter2",
                 'chapter1.re' => '', 'chapter2.re' => '' do |dir, book, files|
      assert_kind_of Book::Part, book.postscripts
      assert_equal '', book.postscripts.name
      assert_equal 2, book.postscripts.chapters.size # XXX: OK?
    end

    mktmpbookdir 'POSTDEF' => 'not_exist' do |dir, book, files|
      assert_raises FileNotFound do
        assert_equal nil, book.postscripts
      end
    end
  end

  def test_parts
    mktmpbookdir do |dir, book, files|
      assert book.parts.empty?
      assert !book.part(0)
      assert !book.part(1)

      tmp = []
      book.each_part { tmp << true }
      assert tmp.empty?
    end

    mktmpbookdir 'CHAPS' => "ch1\nch2\n\nch3" do |dir, book, files|
      parts = book.parts
      assert_equal 2, parts.size
      assert !book.part(0)
      assert book.part(1)
      assert book.part(2)
      assert !book.part(3)

      tmp = []
      book.each_part {|p| tmp << p.number }
      assert_equal [1, 2], tmp
    end

    mktmpbookdir 'CHAPS' => "ch1\nch2\n\nch3",
                 'preface.re' => '' do |dir, book, files|
      parts = book.parts
      assert_equal 3, parts.size
      assert book.part(1)
      assert book.part(2)
      assert !book.part(3)
      assert book.part(nil) # XXX: OK?
      assert_equal 'preface', parts.first.chapters.first.name

      tmp = []
      book.each_part {|p| tmp << p.number }
      assert_equal [nil, 1, 2], tmp
    end

    mktmpbookdir 'CHAPS' => "ch1\nch2\n\nch3",
                 'postscript.re' => '' do |dir, book, files|
      parts = book.parts
      assert_equal 3, parts.size
      assert book.part(1)
      assert book.part(2)
      assert !book.part(3)
      assert book.part(nil) # XXX: OK?
      assert_equal 'postscript', parts.last.chapters.last.name

      tmp = []
      book.each_part {|p| tmp << p.number }
      assert_equal [1, 2, nil], tmp
    end

    mktmpbookdir 'CHAPS' => "ch1\nch2\n\nch3",
                 'preface.re' => '', 'postscript.re' => '' do |dir, book, files|
      parts = book.parts
      assert_equal 4, parts.size
      assert book.part(1)
      assert book.part(2)
      assert !book.part(3)
      assert !book.part(4)
      assert book.part(nil) # XXX: OK?
      assert_equal 'preface', parts.first.chapters.first.name
      assert_equal 'postscript', parts.last.chapters.last.name

      tmp = []
      book.each_part {|p| tmp << p.number }
      assert_equal [nil, 1, 2, nil], tmp
    end
  end

  def test_chapters
    mktmpbookdir 'CHAPS' => "ch1\nch2\n\nch3",
                 'preface.re' => '', 'postscript.re' => '' do |dir, book, files|
      chapters = book.chapters
      assert_equal 5, chapters.size

      ch_names = %w(preface ch1 ch2 ch3 postscript)
      tmp = []
      book.each_chapter {|ch| tmp << ch.name }
      assert_equal ch_names, tmp

      ch_names.each do |name|
        assert book.chapter(name)
        assert_equal name, book.chapter(name).name
      end

      assert_raises ReVIEW::KeyError do
        book.chapter('not exist')
      end
    end

    mktmpbookdir 'CHAPS' => "ch1.txt\nch2.txt\n\nch3.txt",
                 'preface.re' => '', 'postscript.re' => '' do |dir, book, files|
      chapters = book.chapters
      assert_equal 5, chapters.size

      ch_names = %w(preface ch1 ch2 ch3 postscript)
      tmp = []
      book.each_chapter {|ch| tmp << ch.name }
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

  def test_volume
    mktmpbookdir do |dir, book, files|
      assert book.volume
      assert_equal 0, book.volume.bytes
      assert_equal 0, book.volume.chars
      assert_equal 0, book.volume.lines
    end

    mktmpbookdir 'CHAPS' => 'chapter1.re', 'chapter1.re' => '12345' do |dir, book, files|
      assert book.volume
      assert book.volume.bytes > 0
      assert book.volume.chars > 0
      assert book.volume.lines > 0
    end

    mktmpbookdir 'preface.re' => '12345' do |dir, book, files|
      assert_raises Errno::ENOENT do # XXX: OK?
        book.volume
      end

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
end
