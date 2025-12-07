# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'review/ast/command/vivliostyle_maker'

class VivliostyleCLIParserTest < Test::Unit::TestCase
  def test_parse_help
    assert_raise(SystemExit) do
      capture_output do
        ReVIEW::AST::Command::Vivliostyle::CLI::Parser.parse(['--help'])
      end
    end
  end

  def test_parse_debug_option
    options = ReVIEW::AST::Command::Vivliostyle::CLI::Parser.parse(['--debug', 'config.yml'])
    assert_equal true, options.cmd_config['debug']
    assert_equal 'config.yml', options.yamlfile
    assert_nil(options.buildonly)
  end

  def test_parse_only_option
    options = ReVIEW::AST::Command::Vivliostyle::CLI::Parser.parse(['-y', 'ch01,ch02', 'config.yml'])
    assert_equal 'config.yml', options.yamlfile
    assert_equal %w[ch01 ch02], options.buildonly
  end

  def test_parse_ignore_errors_option
    options = ReVIEW::AST::Command::Vivliostyle::CLI::Parser.parse(['--ignore-errors', 'config.yml'])
    assert_equal true, options.cmd_config['ignore-errors']
  end
end

class VivliostyleBuildContextTest < Test::Unit::TestCase
  def setup
    @tmpdir = Dir.mktmpdir
    @config = ReVIEW::Configure.values.merge(
      'bookname' => 'testbook',
      'language' => 'ja'
    )
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def test_setup_build_directory_debug_mode
    context = ReVIEW::AST::Command::Vivliostyle::BuildContext.new(
      config: @config,
      basedir: @tmpdir,
      debug: true
    )
    context.setup_build_directory

    assert context.build_path.end_with?('testbook-vivliostyle')
    assert File.directory?(context.build_path)

    FileUtils.rm_rf(context.build_path)
  end

  def test_entry_files_management
    context = ReVIEW::AST::Command::Vivliostyle::BuildContext.new(
      config: @config,
      basedir: @tmpdir
    )

    context.add_entry_file('ch01.html')
    context.add_entry_file('ch02.html')

    assert_equal %w[ch01.html ch02.html], context.entry_files
  end

  def test_stylesheet_management
    context = ReVIEW::AST::Command::Vivliostyle::BuildContext.new(
      config: @config,
      basedir: @tmpdir
    )

    context.add_stylesheet('style.css')
    assert_equal ['style.css'], context.stylesheets
  end

  def test_source_path
    context = ReVIEW::AST::Command::Vivliostyle::BuildContext.new(
      config: @config,
      basedir: @tmpdir
    )

    assert_equal File.join(@tmpdir, 'images', 'foo.png'), context.source_path('images/foo.png')
  end
end

class VivliostyleLayoutWrapperTest < Test::Unit::TestCase
  def setup
    @tmpdir = Dir.mktmpdir
    @config = ReVIEW::Configure.values.merge(
      'bookname' => 'testbook',
      'language' => 'ja'
    )
    @context = ReVIEW::AST::Command::Vivliostyle::BuildContext.new(
      config: @config,
      basedir: @tmpdir,
      debug: true
    )
    @context.setup_build_directory
    @context.add_stylesheet('theme.css')
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
    FileUtils.rm_rf(@context.build_path) if @context.build_path
  end

  def test_wrap_generates_html
    wrapper = ReVIEW::AST::Command::Vivliostyle::LayoutWrapper.new(context: @context)

    html = wrapper.wrap('<p>Hello</p>', title: 'Test')

    assert_match(/<html lang="ja">/, html)
    assert_match(%r{<title>Test</title>}, html)
    assert_match(%r{<p>Hello</p>}, html)
    assert_match(/theme\.css/, html)
  end

  def test_write_html
    wrapper = ReVIEW::AST::Command::Vivliostyle::LayoutWrapper.new(context: @context)

    wrapper.write_html('test.html', '<html></html>')

    assert File.exist?(@context.output_path('test.html'))
  end
end

class VivliostyleEntryTest < Test::Unit::TestCase
  def setup
    @tmpdir = Dir.mktmpdir
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)

    @config = ReVIEW::Configure.values.merge(
      'bookname' => 'testbook',
      'booktitle' => 'Test Book',
      'language' => 'ja',
      'aut' => 'Test Author'
    )
    ReVIEW::I18n.setup(@config['language'])

    @context = ReVIEW::AST::Command::Vivliostyle::BuildContext.new(
      config: @config,
      basedir: @tmpdir,
      debug: true
    )
    @context.setup_build_directory
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
    FileUtils.rm_rf(@context.build_path) if @context.build_path
  end

  def test_titlepage_entry
    entry = ReVIEW::AST::Command::Vivliostyle::Entries::TitlepageEntry.new(context: @context)

    assert_equal 'titlepage.html', entry.filename
    assert_equal 'Test Book', entry.title

    entry.generate

    assert File.exist?(@context.output_path('titlepage.html'))
    assert_includes(@context.entry_files, 'titlepage.html')

    content = File.read(@context.output_path('titlepage.html'))
    assert_match(/Test Book/, content)
  end

  def test_toc_entry
    # Setup book with chapters
    FileUtils.mkdir_p(File.join(@tmpdir, 'images'))
    File.write(File.join(@tmpdir, 'catalog.yml'), "CHAPS:\n  - ch01.re\n")
    File.write(File.join(@tmpdir, 'ch01.re'), "= Chapter 1\n\nContent")

    book = ReVIEW::Book::Base.new(@tmpdir, config: @config)
    @context.book = book

    entry = ReVIEW::AST::Command::Vivliostyle::Entries::TocEntry.new(context: @context)

    entry.generate

    assert File.exist?(@context.output_path('toc.html'))
    content = File.read(@context.output_path('toc.html'))
    assert_match(/ch01\.html/, content)
  end

  def test_colophon_entry
    entry = ReVIEW::AST::Command::Vivliostyle::Entries::ColophonEntry.new(context: @context)

    assert_equal 'colophon.html', entry.filename

    entry.generate

    assert File.exist?(@context.output_path('colophon.html'))
    assert_includes(@context.entry_files, 'colophon.html')
  end
end

class VivliostyleRunnerTest < Test::Unit::TestCase
  def setup
    @tmpdir = Dir.mktmpdir
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)

    @config = ReVIEW::Configure.values.merge(
      'bookname' => 'testbook',
      'booktitle' => 'Test Book',
      'language' => 'ja',
      'aut' => 'Test Author',
      'vivliostylemaker' => {
        'size' => 'A5',
        'theme' => '@vivliostyle/theme-techbook'
      }
    )
    @context = ReVIEW::AST::Command::Vivliostyle::BuildContext.new(
      config: @config,
      basedir: @tmpdir,
      debug: true
    )
    @context.setup_build_directory
    @context.add_entry_file('ch01.html')
    @context.add_entry_file('ch02.html')
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
    FileUtils.rm_rf(@context.build_path) if @context.build_path
  end

  def test_generate_config
    runner = ReVIEW::AST::Command::Vivliostyle::Runner.new(context: @context)
    runner.generate_config

    config_path = @context.output_path('vivliostyle.config.json')
    assert File.exist?(config_path)

    config_data = JSON.parse(File.read(config_path))
    assert_equal 'Test Book', config_data['title']
    assert_equal 'Test Author', config_data['author']
    assert_equal 'ja', config_data['language']
    assert_equal 'A5', config_data['size']
    assert_equal '@vivliostyle/theme-techbook', config_data['theme']
    assert_equal %w[ch01.html ch02.html], config_data['entry']
    assert_equal 'testbook.pdf', config_data['output']
  end
end

class VivliostyleMakerConfigTest < Test::Unit::TestCase
  def test_configure_has_vivliostylemaker_settings
    config = ReVIEW::Configure.values
    assert config.key?('vivliostylemaker')
    assert_equal './node_modules/.bin/vivliostyle', config['vivliostylemaker']['vivliostyle_path']
    assert_equal 600, config['vivliostylemaker']['timeout']
    assert_equal 'JIS-B5', config['vivliostylemaker']['size']
    assert_nil(config['vivliostylemaker']['theme'])
    assert_equal [], config['vivliostylemaker']['css']
  end
end
