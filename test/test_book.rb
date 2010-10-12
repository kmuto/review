# encoding: utf-8

require 'test_helper'
require 'review/book'

require 'stringio'
require 'tempfile'
require 'tmpdir'

include ReVIEW

module BookTestHelper
  def mktmpbookdir(files = {})
    created_files = {}
    Dir.mktmpdir do |dir|
      files.each_pair do |basename, content|
        path = File.join(dir, basename)
        File.open(path, 'w') {|o| o.print content }
        created_files[basename] = path
      end
      book = Book.new(dir)
      yield(dir, book, created_files)
    end
  end

  def get_instance_variables(obj)
    obj.instance_variables.inject({}) do |memo, name|
      value = obj.instance_variable_get(name)
      if value.instance_variables.empty?
        memo[name] = value
      else
        memo[name] = get_instance_variables(value)
      end
      memo
    end
  end
end

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
      defs = get_instance_variables(Parameters.default)
      pars = get_instance_variables(book.instance_eval { @parameters })
      assert_equal defs, pars
    end

    Dir.mktmpdir do |dir|
      File.open(File.join(dir, 'PARAMS'), 'w') do |o|
        o.puts 'WORDS_FILE = "x_words_file"'
        o.puts 'PAPER = "B5"' # XXX: avoid erros of the last line of Parameters.get_page_metric
      end
      book = Book.load(dir)
      assert_match /x_words_file\z/,
        book.instance_eval { @parameters.reject_file }
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
    book = Book.new(File.dirname(__FILE__))
    assert_equal '.re', book.ext
  end

  def test_read_CHAPS
    Dir.mktmpdir do |dir|
      book = Book.new(dir)
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
      book = Book.new(dir)
      assert !book.part_exist?
      assert_raises Errno::ENOENT do # XXX: OK?
        book.read_PART
      end

      chaps_path = File.join(dir, 'CHAPS')
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
      book = Book.new(dir)
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
    book = Book.new(File.dirname(__FILE__))
    book.setParameter(:test)
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
      assert_equal 'chapter1.re', parts[0].name # XXX: OK?
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
      assert_equal 'part1_chapter1.re', parts[0].name
      assert_equal 2, parts[0].chapters.size
      chaps = parts[0].chapters.map {|ch| [ch.number, ch.name, ch.path] }
      expect = [
        [1, 'part1_chapter1', File.join(dir, 'part1_chapter1.re')],
        [2, 'part1_chapter2', File.join(dir, 'part1_chapter2.re')],
      ]
      assert_equal expect, chaps

      assert_equal 2, parts[1].number
      assert_equal 'part1_chapter2.re', parts[1].name # XXX: OK?
      assert_equal 3, parts[1].chapters.size
      chaps = parts[1].chapters.map {|ch| [ch.number, ch.name, ch.path] }
      expect = [
        [3, 'part2_chapter1', File.join(dir, 'part2_chapter1.re')],
        [4, 'part2_chapter2', File.join(dir, 'part2_chapter2.re')],
        [5, 'part2_chapter3', File.join(dir, 'part2_chapter3.re')],
      ]
      assert_equal expect, chaps

      assert_equal 3, parts[2].number
      assert_equal '',                  parts[2].name # XXX: OK?
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
        params = Parameters.new(:part_file => 'PARTS')
        book = Book.new(dir, params)
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
      assert_kind_of Part, book.prefaces
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
      assert_kind_of Part, book.prefaces
      assert_equal '', book.prefaces.name
      assert_equal 1, book.prefaces.chapters.size
      assert_equal "chapter1", book.prefaces.chapters.first.name
      assert_equal files['chapter1.re'], book.prefaces.chapters.first.path
    end

    mktmpbookdir 'PREDEF' => "chapter1\n\nchapter2",
       'chapter1.re' => '', 'chapter2.re' => '' do |dir, book, files|
      assert_kind_of Part, book.prefaces
      assert_equal '', book.prefaces.name
      assert_equal 2, book.prefaces.chapters.size
      assert_equal "chapter1", book.prefaces.chapters.first.name
      assert_equal files['chapter1.re'], book.prefaces.chapters.first.path
      assert_equal "chapter2", book.prefaces.chapters.last.name
      assert_equal files['chapter2.re'], book.prefaces.chapters.last.path
    end

    mktmpbookdir 'PREDEF' => "chapter1 chapter2",
       'chapter1.re' => '', 'chapter2.re' => '' do |dir, book, files|
      assert_kind_of Part, book.prefaces
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
      assert_kind_of Part, book.prefaces
      assert_equal '', book.prefaces.name
      assert_equal 1, book.prefaces.chapters.size
    end
  end

  def test_postscripts
    mktmpbookdir do |dir, book, files|
      assert_equal nil, book.postscripts
    end

    mktmpbookdir 'appendix.re' => '' do |dir, book, files|
      assert_kind_of Part, book.postscripts
      assert_equal '', book.postscripts.name
      assert_equal 1, book.postscripts.chapters.size
      assert_equal "appendix", book.postscripts.chapters.first.name
      assert_equal files['appendix.re'], book.postscripts.chapters.first.path
      assert_equal nil, book.postscripts.chapters.first.number
    end

    mktmpbookdir 'postscript.re' => '' do |dir, book, files|
      assert_kind_of Part, book.postscripts
      assert_equal '', book.postscripts.name
      assert_equal 1, book.postscripts.chapters.size
      assert_equal "postscript", book.postscripts.chapters.first.name
      assert_equal files['postscript.re'], book.postscripts.chapters.first.path
      assert_equal nil, book.postscripts.chapters.first.number
    end

    mktmpbookdir 'appendix.re' => '',
       'postscript.re' => '' do |dir, book, files|
      assert_kind_of Part, book.postscripts
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
      assert_kind_of Part, book.postscripts
      assert_equal '', book.postscripts.name
      assert_equal 1, book.postscripts.chapters.size
      assert_equal "chapter1", book.postscripts.chapters.first.name
      assert_equal files['chapter1.re'], book.postscripts.chapters.first.path
    end

    mktmpbookdir 'POSTDEF' => "chapter1\n\nchapter2",
       'chapter1.re' => '', 'chapter2.re' => '' do |dir, book, files|
      assert_kind_of Part, book.postscripts
      assert_equal '', book.postscripts.name
      assert_equal 2, book.postscripts.chapters.size
      assert_equal "chapter1", book.postscripts.chapters.first.name
      assert_equal files['chapter1.re'], book.postscripts.chapters.first.path
      assert_equal "chapter2", book.postscripts.chapters.last.name
      assert_equal files['chapter2.re'], book.postscripts.chapters.last.path
    end

    mktmpbookdir 'POSTDEF' => "chapter1 chapter2",
       'chapter1.re' => '', 'chapter2.re' => '' do |dir, book, files|
      assert_kind_of Part, book.postscripts
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
      assert !book.no_part?

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
      assert !book.no_part? # XXX: OK?

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

      assert_raises IndexError do
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
        book2 = Book.new('.')
        assert book2.volume
        assert book2.volume.bytes > 0
        assert book2.volume.chars > 0
        assert book2.volume.lines > 0
      end
    end
  end

  def test_basedir
    Dir.mktmpdir do |dir|
      book = Book.new(dir)
      assert_equal dir, book.basedir
    end
  end
end

class ParametersTest < Test::Unit::TestCase
  def test_s_default
    assert Parameters.default
  end

  def test_s_load
    Tempfile.open('parameters_test') do |io|
      io.puts 'CHAPS_FILE = "x_CHAPS"'
      io.puts 'PAPER = "B5"' # XXX: avoid erros of the last line of Parameters.get_page_metric
      io.close

      params = Parameters.load(io.path)
      assert_equal '/x_CHAPS', params.chapter_file # XXX: OK? (leading / and uninitialized @basedir)
      assert_equal '/CHAPS', params.part_file
    end
  end

  def test_s_get_page_metric
    mod = Module.new
    assert_raises ArgumentError do # XXX: OK?
      params = Parameters.get_page_metric(mod)
      assert params
    end

    mod = Module.new
    mod.module_eval { const_set(:PAPER, 'A5') }
    assert_nothing_raised do
      params = Parameters.get_page_metric(mod)
      assert params
    end

    mod = Module.new
    mod.module_eval { const_set(:PAPER, 'X5') }
    assert_raises ConfigError do
      Parameters.get_page_metric(mod)
    end
  end
end

class PartTest < Test::Unit::TestCase
  def test_initialize
    part = Part.new(nil, nil)
    assert_equal nil, part.number
    assert_equal nil, part.chapters
    assert_equal '', part.name

    part = Part.new(123, [], 'name')
    assert_equal 123, part.number
    assert_equal [], part.chapters
    assert_equal 'name', part.name
  end

  def test_each_chapter
    part = Part.new(nil, [1, 2, 3])

    tmp = []
    part.each_chapter do |ch|
      tmp << ch
    end
    assert_equal [1, 2, 3], tmp
  end

  def test_volume
    part = Part.new(nil, [])
    assert part.volume
    assert_equal 0, part.volume.bytes
    assert_equal 0, part.volume.chars
    assert_equal 0, part.volume.lines

    chs = []
    Tempfile.open('part_test') do |o|
      o.print "12345"
      chs << Chapter.new(nil, nil, nil, o.path)
    end
    Tempfile.open('part_test') do |o|
      o.print "67890"
      chs << Chapter.new(nil, nil, nil, o.path)
    end

    part = Part.new(nil, chs)
    assert part.volume
    assert part.volume.bytes > 0
    assert part.volume.chars > 0
    assert part.volume.lines > 0
  end
end

class ChapterTest < Test::Unit::TestCase
  include BookTestHelper

  def setup
    @utf8_str = "\xe3\x81\x82\xe3\x81\x84\xe3\x81\x86\xe3\x81\x88\xe3\x81\x8a" # "あいうえお"
    @eucjp_str = "\xa4\xa2\xa4\xa4\xa4\xa6\xa4\xa8\xa4\xaa"
    @sjis_str = "\x82\xa0\x82\xa2\x82\xa4\x82\xa6\x82\xa8"
    @jis_str = "\x1b\x24\x42\x24\x22\x24\x24\x24\x26\x24\x28\x24\x2a\x1b\x28\x42"
  end

  def test_s_intern_pathes
    dir1_files = {
      'CHAPS' => "ch1.re\nch2.re\n",
      'ch1.re' => 'ch1',
      'ch2.re' => 'ch2',
    }
    dir2_files = {
      'CHAPS' => "ch1.re\n",
      'ch1.re' => 'ch1',
    }
    mktmpbookdir dir1_files do |dir1, book1, files1|
      mktmpbookdir dir2_files do |dir2, book2, files2|
        paths = (files1.values + files2.values).flatten.grep(/\.re\z/)
        chs = Chapter.intern_pathes(paths)

        assert_equal 3, chs.size
        assert chs[0].book == chs[1].book
        assert chs[0].book != chs[2].book
        assert dir1, chs[0].book.basedir
        assert dir2, chs[2].book.basedir
      end
    end

    dir_files = {
      'CHAPS' => "ch1.re\n",
      'ch1.re' => 'ch1',
    }
    mktmpbookdir dir_files do |dir, book, files|
      paths = files.values.grep(/\.re\z/)
      paths << __FILE__ + ' not exist file.re'
      assert_raises IndexError do # XXX: OK? (KeyError?)
        Chapter.intern_pathes(paths)
      end
    end

    dir_files = {
      'ch1.re' => 'ch1 not in CHAPS',
      'ch2.re' => 'ch2 not in CHAPS',
    }
    mktmpbookdir dir_files do |dir, book, files|
      paths = files.values.grep(/\.re\z/)
      assert_nothing_raised do
        Chapter.intern_pathes(paths)
      end
    end

    dir_files = {
      'CHAPS' => "ch1.re\n",
      'ch1.re' => 'ch1',
      'ch2.re' => 'ch2 not in CHAPS',
    }
    mktmpbookdir dir_files do |dir, book, files|
      paths = files.values.grep(/\.re\z/)
      assert_raises IndexError do # XXX: OK? (should not be raised?)
        Chapter.intern_pathes(paths)
      end
    end

    dir_files = {
      'CHAPS' => "ch1.re\n",
      'ch1.re' => 'ch1',
      'preface.re' => 'preface',
    }
    mktmpbookdir dir_files do |dir, book, files|
      paths = files.values.grep(/\.re\z/)
      assert_nothing_raised do
        Chapter.intern_pathes(paths)
      end
    end
  end

  def test_s_for_stdin
    assert Chapter.for_stdin
  end

  def test_s_for_path
    assert Chapter.for_path(1, __FILE__)
  end

  def test_initialize
    ch = Chapter.new(:book, :number, :name, '/foo/bar', :io)
    assert_equal :book, ch.env
    assert_equal :book, ch.book
    assert_equal :number, ch.number
    assert_equal '/foo/bar', ch.path
    assert_equal "#<ReVIEW::Chapter number /foo/bar>", ch.inspect
  end

  def test_dirname_and_basename
    ch = Chapter.new(nil, nil, nil, nil, nil)
    assert_equal nil, ch.dirname
    assert_equal nil, ch.basename

    ch = Chapter.new(nil, nil, nil, '/foo/bar', nil)
    assert_equal '/foo', ch.dirname
    assert_equal 'bar', ch.basename

    ch = Chapter.new(nil, nil, nil, 'bar', nil)
    assert_equal '.', ch.dirname
    assert_equal 'bar', ch.basename
  end

  def test_name
    ch = Chapter.new(nil, nil, 'foo', nil)
    assert_equal 'foo', ch.name

    ch = Chapter.new(nil, nil, 'foo.bar', nil)
    assert_equal 'foo', ch.name

    ch = Chapter.new(nil, nil, nil, nil)
    assert_raises(TypeError) { ch.name } # XXX: OK?
  end

  def test_setParameter
    ch = Chapter.new(nil, nil, nil, nil, nil)
    ch.setParameter(:test)
    assert_equal :test, ch.instance_eval {@param}
  end

  def test_open
    ch = Chapter.new(nil, nil, nil, __FILE__, :io)
    assert_equal :io, ch.open
    assert_equal [:io], ch.open {|io| [io] }

    ch = Chapter.new(nil, nil, nil, __FILE__)
    assert_equal __FILE__, ch.open.path
    assert_equal [__FILE__], ch.open {|io| [io.path] }
  end

  def test_size
    ch = Chapter.new(nil, nil, nil, __FILE__, :io)
    assert_equal File.size(__FILE__), ch.size

    File.open(__FILE__, 'r') do |i|
      ch = Chapter.new(nil, nil, nil, nil, i)
      assert_raises(TypeError) do # XXX: OK?
        ch.size
      end
    end
  end

  def test_title
    io = StringIO.new
    ch = Chapter.new(nil, nil, nil, nil, io)
    ch.setParameter({})
    assert_equal '', ch.title

    io = StringIO.new("=1\n=2\n")
    ch = Chapter.new(nil, nil, nil, nil, io)
    ch.setParameter({})
    assert_equal '1', ch.title


    [
      ['EUC', @eucjp_str],
      ['SJIS', @sjis_str],
      ['JIS', @jis_str],
      ['XYZ', @eucjp_str],
    ].each do |enc, instr|
      io = StringIO.new("= #{instr}\n")
      ch = Chapter.new(nil, nil, nil, nil, io)
      ch.setParameter({'inencoding' => enc})
      assert_equal @utf8_str, ch.title
      assert_equal @utf8_str, ch.instance_eval { @title }
    end
  end

  def test_content
    [
      ['EUC', @eucjp_str],
      ['SJIS', @sjis_str],
      ['JIS', @jis_str],
      ['XYZ', @eucjp_str],
    ].each do |enc, instr|
      tf = Tempfile.new('chapter_test')
      begin
        tf.print instr
        tf.close

        ch = Chapter.new(nil, nil, nil, tf.path)
        ch.setParameter({'inencoding' => enc})
        assert_equal @utf8_str, ch.content
        assert_equal @utf8_str, ch.instance_eval { @content }
      ensure
        tf.close(true)
      end

      tf1 = Tempfile.new('chapter_test1')
      tf2 = Tempfile.new('chapter_test2')
      begin
        tf1.puts instr
        tf1.puts instr
        tf1.close
        tf2.puts instr
        tf1.close

        ch = Chapter.new(nil, nil, nil, tf1.path, tf2)
        ch.setParameter({'inencoding' => enc})
        assert_equal "#{@utf8_str}\n#{@utf8_str}\n", ch.content # XXX: OK?
      ensure
        tf1.close(true)
        tf2.close(true)
      end
    end
  end

  def test_lines
    lines = ["1\n", "2\n", "3"]
    tf = Tempfile.new('chapter_test')
    tf.print lines.join('')
    tf.close

    ch = Chapter.new(nil, nil, nil, tf.path)
    ch.setParameter({})
    assert_equal lines, ch.lines

    lines = ["1\n", "2\n", "3"]
    tf1 = Tempfile.new('chapter_test1')
    tf1.print lines.join('')
    tf1.close
    tf2 = Tempfile.new('chapter_test2')
    tf2.puts lines.join('')
    tf2.puts lines.join('')
    tf2.close

    ch = Chapter.new(nil, nil, nil, tf1.path, tf2.path)
    ch.setParameter({})
    assert_equal lines, ch.lines # XXX: OK?
  end

  def test_volume
    content = "abc\ndef"
    tf1 = Tempfile.new('chapter_test1')
    tf1.print content
    tf1.close
    tf2 = Tempfile.new('chapter_test2')
    tf2.print content
    tf2.print content
    tf2.close

    ch = Chapter.new(nil, nil, nil, tf1.path)
    assert ch.volume
    assert_equal content.gsub(/\s/, '').size, ch.volume.bytes

    ch = Chapter.new(nil, nil, nil, tf1.path, tf2)
    assert ch.volume
    assert_equal content.gsub(/\s/, '').size, ch.volume.bytes # XXX: OK?
  end

  def test_on_CHAPS?
    mktmpbookdir 'CHAPS' => "chapter1.re\nchapter2.re",
        'chapter1.re' => '12345', 'preface.re' => 'abcde' do |dir, book, files|
      ch1 = Chapter.new(book, 1, 'chapter1', files['chapter1.re'])
      pre = Chapter.new(book, nil, 'preface', files['preface.re'])

      assert ch1.on_CHAPS?
      assert !pre.on_CHAPS?

      ch2_path = File.join(dir, 'chapter2.er')
      File.open(ch2_path, 'w') {}
      ch2 = Chapter.new(book, 2, 'chapter2', ch2_path)

      ch3_path = File.join(dir, 'chapter3.er')
      File.open(ch3_path, 'w') {}
      ch3 = Chapter.new(book, 3, 'chapter3', ch3_path)

      assert ch2.on_CHAPS?
      assert !ch3.on_CHAPS?
    end
  end

  def test_list_index
    do_test_index(<<E, ListIndex, :list_index, :list)
//list
//listnum [abc]
//list [def]
//table [def]
//table [others]
E
  end

  def test_table_index
    do_test_index(<<E, TableIndex, :table_index, :table)
//table
//table [abc]
//table [def]
//list [def]
//list [others]
E
  end

  def test_footnote_index
    content = <<E
//footnote
//footnote [abc][text...]
//footnote [def][text...]
//footnote [xyz]
//list [def]
//list [others]
E
    do_test_index(content, FootnoteIndex, :footnote_index, :footnote) do |ch|
      assert_raises IndexError do
        ch.footnote('xyz')
      end
    end
  end

  def test_bibpaper
    do_test_index(<<E, BibpaperIndex, :bibpaper_index, :bibpaper, :filename => 'bib.re')
//bibpaper
//bibpaper [abc][text...]
//bibpaper [def][text...]
//bibpaper [xyz]
//list [def]
//list [others]
E
    assert_raises FileNotFound do
      do_test_index('', BibpaperIndex, :bibpaper_index, :bibpaper, :filename => 'bib')
    end
  end

  def test_headline_index
    do_test_index(<<E, HeadlineIndex, :headline_index, :headline, :propagate => false)
==
== abc
== def
=== def
//table others
E
  end

  def test_image
    do_test_index(<<E, ImageIndex, :image_index, :image)
//image
//image [abc]
//image [def]
//list [def]
//list [others]
E

    do_test_index(<<E, NumberlessImageIndex, :numberless_image_index, :image, :propagate => false)
//numberlessimage
//numberlessimage [abc]
//numberlessimage [def]
//list [def]
//list [others]
E

    do_test_index(<<E, ImageIndex, :image_index, :image)
//image
//numberlessimage [abc]
//image [def]
//list [def]
//list [others]
E

    do_test_index(<<E, NumberlessImageIndex, :numberless_image_index, :image, :propagate => false)
//image
//numberlessimage [abc]
//image [def]
//list [def]
//list [others]
E
  end

  def do_test_index(content, klass, list_method, ref_method, opts = {})
    Dir.mktmpdir do |dir|
      path = File.join(dir, opts[:filename] || 'chapter.re')

      book = Book.new(dir)

      ch = nil
      File.open(path, 'w') do |o|
        o.print content
        ch = Chapter.new(book, 1, 'chapter', o.path)
      end

      ch.setParameter({:__test__ => 54321})
      assert_kind_of klass, ch.__send__(list_method)
      tmp = ch.__send__(list_method).instance_eval do
        if @param
          @param[:__test__]
        else
          @param
        end
      end
      if opts[:propagate] == false
        assert_equal nil, tmp
      else
        assert_equal 54321, tmp
      end

      assert ch.__send__(ref_method, 'abc')
      assert ch.__send__(ref_method, 'def')
      assert_raises IndexError do
        ch.__send__(ref_method, nil)
      end
      assert_raises IndexError do
        ch.__send__(ref_method, 'others')
      end
      assert_raises IndexError do
        ch.__send__(ref_method, 'not exist id')
      end

      yield(ch) if block_given?
    end
  end
end

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
        cs = ChapterSet.for_pathes(paths)
      end
      assert_equal 2, cs.chapters.size
    end
  end

  def test_s_for_argv
    begin
      paths = []
      ChapterSet.class_eval { const_set(:ARGV, paths) }

      dir_files = {
        'ch1.re' => 'ch1',
        'ch2.re' => 'ch2',
      }
      mktmpbookdir dir_files do |dir, book, files|
        paths.concat files.values.grep(/\.re\z/)
        cs = nil
        assert_nothing_raised do
          cs = ChapterSet.for_argv
        end
        assert_equal 2, cs.chapters.size
        assert_equal ['ch1', 'ch2'], cs.chapters.map(&:name).sort
      end

    ensure
      ChapterSet.class_eval { remove_const(:ARGV) }
    end

    begin
      $stdin = StringIO.new('abc')
      cs = nil
      assert_nothing_raised do
        cs = ChapterSet.for_argv
      end
      assert_equal 1, cs.chapters.size
      assert_equal '-', cs.chapters.first.name

    ensure
      $stdin = STDIN
    end
  end

  def test_no_part?
    cs = ChapterSet.new([])
    assert cs.no_part?

    ch = Chapter.new(nil, nil, nil, nil, StringIO.new)
    cs = ChapterSet.new([ch])
    assert cs.no_part?
  end

  def test_chapters
    ch1 = Chapter.new(nil, 123, nil, nil, StringIO.new)
    ch2 = Chapter.new(nil, 456, nil, nil, StringIO.new)
    cs = ChapterSet.new([ch1, ch2])
    assert_equal [123, 456], cs.chapters.map(&:number)

    tmp = [ch1, ch2]
    cs.each_chapter do |ch|
      assert tmp.delete(ch)
    end
    assert tmp.empty?
  end

  def test_ext
    cs = ChapterSet.new([])
    assert_equal '.re', cs.ext
  end
end
