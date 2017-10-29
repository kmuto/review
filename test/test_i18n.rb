require 'test_helper'
require 'review'
require 'tmpdir'

class I18nTest < Test::Unit::TestCase
  include ReVIEW

  def test_load_locale_yml
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, 'locale.yml')
        File.open(file, 'w') { |f| f.write(%Q(locale: ja\nfoo: "bar"\n)) }
        I18n.setup
        assert_equal 'bar', I18n.t('foo')
      end
    end
  end

  def test_load_locale_yaml
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, 'locale.yaml')
        File.open(file, 'w') { |f| f.write(%Q(locale: ja\nfoo: "bar"\n)) }
        assert_raise ReVIEW::ConfigError do
          I18n.setup
        end
      end
    end
  end

  def test_load_foo_yaml
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, 'foo.yml')
        File.open(file, 'w') { |f| f.write(%Q(locale: ja\nfoo: "bar"\n)) }
        I18n.setup('ja', 'foo.yml')
        assert_equal 'bar', I18n.t('foo')
      end
    end
  end

  def test_update_foo_yaml
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, 'foo.yml')
        File.open(file, 'w') { |f| f.write(%Q(locale: ja\nfoo: "bar"\n)) }
        i18n = ReVIEW::I18n.new('ja')
        i18n.update_localefile(File.join(Dir.pwd, 'foo.yml'))
        assert_equal 'bar', i18n.t('foo')
      end
    end
  end

  def test_update_foo_yaml_i18nclass
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, 'foo.yml')
        File.open(file, 'w') { |f| f.write(%Q(locale: ja\nfoo: "bar"\n)) }
        I18n.setup('ja', 'foo.yml')
        assert_equal 'bar', I18n.t('foo')
      end
    end
  end

  def test_load_locale_yml_i18n
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, 'locale.yml')
        File.open(file, 'w') { |f| f.write(%Q(ja:\n  foo: "bar"\nen:\n  foo: "buz"\n)) }
        I18n.setup
        assert_equal 'bar', I18n.t('foo')
        assert_equal '図', I18n.t('image')
        I18n.setup('en')
        assert_equal 'buz', I18n.t('foo')
        assert_equal 'Figure ', I18n.t('image')
      end
    end
  end

  def test_load_locale_invalid_yml
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, 'locale.yml')
        File.open(file, 'w') { |f| f.write(%Q(local: ja\nfoo: "bar"\n)) }
        assert_raises(ReVIEW::KeyError) do
          I18n.setup
        end
      end
    end
  end

  def test_custom_format
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, 'locale.yml')
        File.open(file, 'w') { |f| f.write("locale: ja\nchapter: 第%pa章") }
        I18n.setup('ja')
        assert_equal '第a章', I18n.t('chapter', 1)

        File.open(file, 'w') { |f| f.write("locale: ja\nchapter: 第%pA章") }
        I18n.setup('ja')
        assert_equal '第B章', I18n.t('chapter', 2)

        File.open(file, 'w') { |f| f.write("locale: ja\nchapter: 第%pAW章") }
        I18n.setup('ja')
        assert_equal '第Ｂ章', I18n.t('chapter', 2)

        File.open(file, 'w') { |f| f.write("locale: ja\nchapter: 第%paW章") }
        I18n.setup('ja')
        assert_equal '第ｂ章', I18n.t('chapter', 2)

        File.open(file, 'w') { |f| f.write("locale: ja\nchapter: 第%pR章") }
        I18n.setup('ja')
        assert_equal '第I章', I18n.t('chapter', 1)

        File.open(file, 'w') { |f| f.write("locale: ja\nchapter: 第%pr章") }
        I18n.setup('ja')
        assert_equal '第ii章', I18n.t('chapter', 2)

        File.open(file, 'w') { |f| f.write("locale: ja\nchapter: 第%pRW章") }
        I18n.setup('ja')
        assert_equal '第Ⅻ章', I18n.t('chapter', 12)

        File.open(file, 'w') { |f| f.write("locale: ja\nchapter: 第%pJ章") }
        I18n.setup('ja')
        assert_equal '第二十七章', I18n.t('chapter', 27)

        File.open(file, 'w') { |f| f.write("locale: ja\nchapter: 第%pdW章") }
        I18n.setup('ja')
        assert_equal '第１章', I18n.t('chapter', 1)

        File.open(file, 'w') { |f| f.write("locale: ja\nchapter: 第%pdW章") }
        I18n.setup('ja')
        assert_equal '第27章', I18n.t('chapter', 27)

        File.open(file, 'w') { |f| f.write("locale: ja\nchapter: 第%pDW章") }
        I18n.setup('ja')
        assert_equal '第１章', I18n.t('chapter', 1)

        File.open(file, 'w') { |f| f.write("locale: ja\nchapter: 第%pDW章") }
        I18n.setup('ja')
        assert_equal '第２７章', I18n.t('chapter', 27)

        File.open(file, 'w') { |f| f.write("locale: ja\npart: Part %pRW") }
        I18n.setup('ja')
        assert_equal 'Part ０', I18n.t('part', 0)

        File.open(file, 'w') { |f| f.write("locale: ja\npart: 第%pJ部") }
        I18n.setup('ja')
        assert_equal '第一部', I18n.t('part', 1)
      end
    end
  end

  def test_custom_format_numbers
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, 'locale.yml')

        File.open(file, 'w') { |f| f.write %Q(locale: ja\nformat_number_header: "%s-%pA:") }
        I18n.setup('ja')
        assert_equal '1-B:', I18n.t('format_number_header', [1, 2])

        File.open(file, 'w') { |f| f.write %Q(locale: ja\nformat_number_header: "%s.%pa:") }
        I18n.setup('ja')
        assert_equal '2.c:', I18n.t('format_number_header', [2, 3])

        File.open(file, 'w') { |f| f.write %Q(locale: ja\nformat_number_header: "%pA,%pAW:") }
        I18n.setup('ja')
        assert_equal 'C,Ｄ:', I18n.t('format_number_header', [3, 4])

        File.open(file, 'w') { |f| f.write %Q(locale: ja\nformat_number_header: "%pJ・%pJ:") }
        I18n.setup('ja')
        assert_equal '十二・二十六:', I18n.t('format_number_header', [12, 26])

        File.open(file, 'w') { |f| f.write %Q(locale: ja\nformat_number_header: "%pdW―%pdW:") }
        I18n.setup('ja')
        assert_equal '３―12:', I18n.t('format_number_header', [3, 12])
      end
    end
  end

  def test_format_with_mismatched_number_of_arguments
    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        file = File.join(dir, 'locale.yml')

        File.open(file, 'w') { |f| f.write %Q(locale: ja\nformat_number_header: "%2$d") }
        I18n.setup('ja')
        assert_equal '10', I18n.t('format_number_header', [1, 10])

        File.open(file, 'w') { |f| f.write %Q(locale: ja\nformat_number_header: "%2$d-%1$d") }
        I18n.setup('ja')
        # ERROR: returns raw format
        assert_equal '%2$d-%1$d', I18n.t('format_number_header', [1])
      end
    end
  end

  def test_ja
    I18n.setup('ja')
    assert_equal '図', I18n.t('image')
    assert_equal '表', I18n.t('table')
    assert_equal '第1章', I18n.t('chapter', 1)
    assert_equal 'etc', I18n.t('etc')
  end

  def test_ja_with_user_i18n
    i18n = I18n.new('ja')
    i18n.update({ 'image' => 'ず' }, 'ja')
    assert_equal 'ず', i18n.t('image')
    assert_equal '表', i18n.t('table')
    assert_equal '第1章', i18n.t('chapter', 1)
    assert_equal 'etc', i18n.t('etc')
  end

  def test_en
    I18n.setup 'en'
    assert_equal 'Figure ', I18n.t('image')
    assert_equal 'Table ', I18n.t('table')
    assert_equal 'Chapter 1', I18n.t('chapter', 1)
    assert_equal 'etc', I18n.t('etc')
  end

  def test_nil
    I18n.setup 'nil'
    assert_equal 'image', I18n.t('image')
    assert_equal 'table', I18n.t('table')
    assert_equal 'etc', I18n.t('etc')
  end

  def test_htmlbuilder
    _setup_htmlbuilder
    actual = compile_block("={test} this is test.\n")
    assert_equal %Q(<h1 id="test"><a id="h1"></a><span class="secno">Chapter 1. </span>this is test.</h1>\n), actual
  end

  def _setup_htmlbuilder
    I18n.setup 'en'
    @builder = HTMLBuilder.new
    @config = ReVIEW::Configure[
      'secnolevel' => 2, # for IDGXMLBuilder, HTMLBuilder
      'stylesheet' => nil, # for HTMLBuilder
      'ext' => '.re'
    ]
    @book = Book::Base.new('.')
    @book.config = @config
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
  end

  def test_update
    i18n = ReVIEW::I18n.new('ja')
    hash = { 'foo' => 'bar' }
    i18n.update(hash)
    assert_equal 'bar', i18n.t('foo')
  end

  def test_update_newlocale
    i18n = ReVIEW::I18n.new('ja')
    hash = { 'foo' => 'bar' }
    i18n.update(hash, 'abc')
    i18n.locale = 'abc'
    assert_equal 'bar', i18n.t('foo')
  end

  def test_ja_appendix_alphabet
    i18n = I18n.new('ja')
    i18n.update({ 'appendix' => '付録%pA' }, 'ja')
    assert_equal '付録A', i18n.t('appendix', 1)
    assert_equal '付録B', i18n.t('appendix', 2)
    assert_equal '付録C', i18n.t('appendix', 3)
  end

  def test_ja_part
    i18n = I18n.new('ja')
    assert_equal '第III部', i18n.t('part', 3)
    assert_equal 'III', i18n.t('part_short', 3)
    i18n.update({ 'part' => '第%pRW部' }, 'ja')
    i18n.update({ 'part_short' => '%pRW' }, 'ja')
    assert_equal '第Ⅲ部', i18n.t('part', 3)
    assert_equal 'Ⅲ', i18n.t('part_short', 3)
  end

  def test_i18n_error
    I18n.setup
    assert_raises NotImplementedError do
      I18n.i18n('ja')
    end
    assert_raises NotImplementedError do
      I18n.i18n('ja', {})
    end
  end

  def teardown
    I18n.setup 'ja'
  end
end
