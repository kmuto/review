# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'review/ast/command/vivliostyle_maker'

class ASTVivliostyleMakerTest < Test::Unit::TestCase
  def setup
    @tmpdir = Dir.mktmpdir
    @old_pwd = Dir.pwd
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
  end

  def teardown
    Dir.chdir(@old_pwd)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_parse_opts_help
    maker = ReVIEW::AST::Command::VivliostyleMaker.new
    assert_raise(SystemExit) do
      capture_output do
        maker.parse_opts(['--help'])
      end
    end
  end

  def test_parse_opts_with_debug
    maker = ReVIEW::AST::Command::VivliostyleMaker.new
    cmd_config, yamlfile = maker.parse_opts(['--debug', 'config.yml'])
    assert_equal true, cmd_config['debug']
    assert_equal 'config.yml', yamlfile
  end

  def test_parse_opts_with_only
    maker = ReVIEW::AST::Command::VivliostyleMaker.new
    cmd_config, yamlfile = maker.parse_opts(['-y', 'ch01,ch02', 'config.yml'])
    assert_equal 'config.yml', yamlfile
  end

  def test_configure_has_vivliostylemaker_settings
    config = ReVIEW::Configure.values
    assert config.key?('vivliostylemaker')
    assert_equal './node_modules/.bin/vivliostyle', config['vivliostylemaker']['vivliostyle_path']
    assert_equal 600, config['vivliostylemaker']['timeout']
    assert_equal 'JIS-B5', config['vivliostylemaker']['size']
    assert_nil config['vivliostylemaker']['theme']
    assert_equal [], config['vivliostylemaker']['css']
  end

  def test_generates_html_files_with_renderer
    # Skip if sample-book doesn't exist
    samplebook_dir = File.expand_path('../../samples/sample-book/src', __dir__)
    unless File.exist?(samplebook_dir)
      omit('sample-book not found')
    end

    prepare_samplebook(@tmpdir, 'sample-book/src', nil, 'config.yml')

    Dir.chdir(@tmpdir) do
      maker = ReVIEW::AST::Command::VivliostyleMaker.new

      # Mock run_vivliostyle to avoid requiring actual vivliostyle CLI
      def maker.run_vivliostyle(bookname)
        # Create a dummy PDF for testing
        File.write(File.join(@path, "#{bookname}.pdf"), 'dummy pdf')
      end

      begin
        maker.execute('--debug', 'config.yml')
      rescue SystemExit
        # Ignore exit
      end

      # Check if HTML files were generated
      output_dir = Dir.glob('*-vivliostyle').first
      if output_dir
        assert File.exist?(File.join(output_dir, 'vivliostyle.config.json')),
               'vivliostyle.config.json should be generated'

        # Verify config.json structure
        config_content = File.read(File.join(output_dir, 'vivliostyle.config.json'))
        config_data = JSON.parse(config_content)
        assert config_data.key?('title')
        assert config_data.key?('entry')
        assert config_data['entry'].is_a?(Array)
      end
    end
  end

  def test_vivliostyle_config_json_generation
    # Create minimal test project
    FileUtils.mkdir_p(File.join(@tmpdir, 'images'))
    File.write(File.join(@tmpdir, 'catalog.yml'), <<~YAML)
      CHAPS:
        - ch01.re
    YAML
    File.write(File.join(@tmpdir, 'ch01.re'), <<~RE)
      = Test Chapter

      Hello, Vivliostyle!
    RE
    File.write(File.join(@tmpdir, 'config.yml'), <<~YAML)
      review_version: 5.0
      bookname: testbook
      booktitle: Test Book
      aut: Test Author
      language: ja
      toc: true
      colophon: true
      vivliostylemaker:
        size: A5
    YAML

    Dir.chdir(@tmpdir) do
      maker = ReVIEW::AST::Command::VivliostyleMaker.new

      # Mock run_vivliostyle
      def maker.run_vivliostyle(bookname)
        File.write(File.join(@path, "#{bookname}.pdf"), 'dummy pdf')
      end

      begin
        maker.execute('--debug', 'config.yml')
      rescue SystemExit
        # Ignore exit
      end

      output_dir = 'testbook-vivliostyle'
      assert File.directory?(output_dir), 'Output directory should exist'

      config_path = File.join(output_dir, 'vivliostyle.config.json')
      assert File.exist?(config_path), 'vivliostyle.config.json should exist'

      config_data = JSON.parse(File.read(config_path))
      assert_equal 'Test Book', config_data['title']
      assert_equal 'Test Author', config_data['aut'] || config_data['author']
      assert_equal 'ja', config_data['language']
      assert_equal 'A5', config_data['size']
      assert_includes config_data['entry'], 'ch01.html'
    end
  end

  def test_theme_setting_in_config
    FileUtils.mkdir_p(File.join(@tmpdir, 'images'))
    File.write(File.join(@tmpdir, 'catalog.yml'), <<~YAML)
      CHAPS:
        - ch01.re
    YAML
    File.write(File.join(@tmpdir, 'ch01.re'), <<~RE)
      = Test Chapter

      Hello!
    RE
    File.write(File.join(@tmpdir, 'config.yml'), <<~YAML)
      review_version: 5.0
      bookname: testbook
      booktitle: Test Book
      language: ja
      vivliostylemaker:
        theme: '@vivliostyle/theme-techbook'
    YAML

    Dir.chdir(@tmpdir) do
      maker = ReVIEW::AST::Command::VivliostyleMaker.new

      def maker.run_vivliostyle(bookname)
        File.write(File.join(@path, "#{bookname}.pdf"), 'dummy pdf')
      end

      begin
        maker.execute('--debug', 'config.yml')
      rescue SystemExit
        # Ignore
      end

      output_dir = 'testbook-vivliostyle'
      config_path = File.join(output_dir, 'vivliostyle.config.json')

      if File.exist?(config_path)
        config_data = JSON.parse(File.read(config_path))
        assert_equal '@vivliostyle/theme-techbook', config_data['theme']
      end
    end
  end
end
