# frozen_string_literal: true

require_relative 'test_helper'
require 'review/highlighter'
require 'review/logger'
require 'stringio'

class TestHighlighter < Test::Unit::TestCase
  def setup
    @default_config = {}
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
  end

  def test_initialize_with_empty_config
    highlighter = ReVIEW::Highlighter.new
    assert_equal({}, highlighter.config)
  end

  def test_initialize_with_config
    config = { 'highlight' => { 'html' => 'rouge' } }
    highlighter = ReVIEW::Highlighter.new(config)
    assert_equal(config, highlighter.config)
  end

  def test_highlight_disabled_by_default
    highlighter = ReVIEW::Highlighter.new(@default_config)
    assert_equal(false, highlighter.highlight?('html'))
    assert_equal(false, highlighter.highlight?('latex'))
  end

  def test_highlight_enabled_for_html_with_rouge
    config = { 'highlight' => { 'html' => 'rouge' } }
    highlighter = ReVIEW::Highlighter.new(config)
    assert_true(highlighter.highlight?('html'))
    assert_equal(false, highlighter.highlight?('latex'))
  end

  def test_highlight_enabled_for_html_with_pygments
    config = { 'highlight' => { 'html' => 'pygments' } }
    highlighter = ReVIEW::Highlighter.new(config)
    assert_true(highlighter.highlight?('html'))
    assert_equal(false, highlighter.highlight?('latex'))
  end

  def test_highlight_enabled_for_latex
    config = { 'highlight' => { 'latex' => 'listings' } }
    highlighter = ReVIEW::Highlighter.new(config)
    assert_equal(false, highlighter.highlight?('html'))
    assert_true(highlighter.highlight?('latex'))
  end

  def test_highlight_enabled_for_both_formats
    config = { 'highlight' => { 'html' => 'rouge', 'latex' => 'listings' } }
    highlighter = ReVIEW::Highlighter.new(config)
    assert_true(highlighter.highlight?('html'))
    assert_true(highlighter.highlight?('latex'))
  end

  def test_highlight_format_aliases
    config = { 'highlight' => { 'latex' => 'listings' } }
    highlighter = ReVIEW::Highlighter.new(config)
    assert_true(highlighter.highlight?('latex'))
    assert_true(highlighter.highlight?('tex'))
  end

  def test_highlight_when_disabled_returns_original_body
    config = {}
    highlighter = ReVIEW::Highlighter.new(config)
    body = 'puts "hello world"'

    result = highlighter.highlight(body: body, format: 'html')
    assert_equal(body, result)
  end

  def test_highlight_html_with_unknown_highlighter
    config = { 'highlight' => { 'html' => 'unknown' } }
    highlighter = ReVIEW::Highlighter.new(config)
    body = 'puts "hello world"'

    result = highlighter.highlight(body: body, format: 'html')
    assert_equal(body, result)
    assert_match(/Unknown HTML highlighter: unknown/, @log_io.string)
  end

  def test_highlight_latex_returns_original_body
    config = { 'highlight' => { 'latex' => 'listings' } }
    highlighter = ReVIEW::Highlighter.new(config)
    body = 'puts "hello world"'

    result = highlighter.highlight(body: body, format: 'latex')
    assert_equal(body, result)
  end

  def test_normalize_lexer_name_with_nil
    highlighter = ReVIEW::Highlighter.new(@default_config)
    assert_equal('text', highlighter.normalize_lexer_name(nil))
  end

  def test_normalize_lexer_name_with_empty_string
    highlighter = ReVIEW::Highlighter.new(@default_config)
    assert_equal('text', highlighter.normalize_lexer_name(''))
  end

  def test_normalize_lexer_name_with_custom_default
    config = { 'highlight' => { 'lang' => 'ruby' } }
    highlighter = ReVIEW::Highlighter.new(config)
    assert_equal('ruby', highlighter.normalize_lexer_name(nil))
  end

  def test_normalize_lexer_name_javascript_aliases
    highlighter = ReVIEW::Highlighter.new(@default_config)
    assert_equal('javascript', highlighter.normalize_lexer_name('js'))
    assert_equal('javascript', highlighter.normalize_lexer_name('javascript'))
  end

  def test_normalize_lexer_name_ruby_aliases
    highlighter = ReVIEW::Highlighter.new(@default_config)
    assert_equal('ruby', highlighter.normalize_lexer_name('rb'))
    assert_equal('ruby', highlighter.normalize_lexer_name('ruby'))
  end

  def test_normalize_lexer_name_shell_aliases
    highlighter = ReVIEW::Highlighter.new(@default_config)
    assert_equal('shell', highlighter.normalize_lexer_name('sh'))
    assert_equal('shell', highlighter.normalize_lexer_name('bash'))
    assert_equal('shell', highlighter.normalize_lexer_name('shell'))
  end

  def test_normalize_lexer_name_cpp_alias
    highlighter = ReVIEW::Highlighter.new(@default_config)
    assert_equal('cpp', highlighter.normalize_lexer_name('c++'))
  end

  def test_build_pygments_options_basic
    highlighter = ReVIEW::Highlighter.new(@default_config)
    options = highlighter.build_pygments_options

    expected = {
      nowrap: true,
      noclasses: true
    }
    assert_equal(expected, options)
  end

  def test_build_pygments_options_with_linenum
    highlighter = ReVIEW::Highlighter.new(@default_config)
    options = highlighter.build_pygments_options(linenum: true)

    expected = {
      nowrap: false,
      noclasses: true,
      linenos: 'inline'
    }
    assert_equal(expected, options)
  end

  def test_build_pygments_options_with_linenum_and_start
    highlighter = ReVIEW::Highlighter.new(@default_config)
    options = highlighter.build_pygments_options(
      linenum: true,
      options: { linenostart: 5 }
    )

    expected = {
      nowrap: false,
      noclasses: true,
      linenos: 'inline',
      linenostart: 5
    }
    assert_equal(expected, options)
  end

  def test_build_pygments_options_with_custom_options
    highlighter = ReVIEW::Highlighter.new(@default_config)
    custom_options = { style: 'github', tabsize: 4 }
    options = highlighter.build_pygments_options(
      options: custom_options
    )

    expected = {
      nowrap: true,
      noclasses: true,
      style: 'github',
      tabsize: 4
    }
    assert_equal(expected, options)
  end

  def test_highlight_html_with_rouge_fallback_when_gem_missing
    config = { 'highlight' => { 'html' => 'rouge' } }
    highlighter = ReVIEW::Highlighter.new(config)

    body = 'puts "hello world"'

    result = highlighter.highlight_html(body: body, lexer: 'ruby')
    assert_not_equal(body, result)
  end

  def test_highlight_html_with_pygments_fallback_when_gem_missing
    config = { 'highlight' => { 'html' => 'pygments' } }
    highlighter = ReVIEW::Highlighter.new(config)
    skip('Pygments gem not available') unless highlighter.pygments_available?

    body = 'puts "hello world"'

    result = highlighter.highlight_html(body: body, lexer: 'ruby')
    assert_not_equal(body, result)
  end

  def test_highlight_with_lexer_symbol
    config = { 'highlight' => { 'html' => 'rouge' } }
    highlighter = ReVIEW::Highlighter.new(config)

    body = 'puts "hello world"'

    result = highlighter.highlight(body: body, lexer: :ruby, format: 'html')
    assert_not_equal(body, result)
  end

  def test_highlight_with_linenum_option
    config = { 'highlight' => { 'html' => 'rouge' } }
    highlighter = ReVIEW::Highlighter.new(config)

    body = 'puts "hello world"'

    result = highlighter.highlight(
      body: body,
      lexer: 'ruby',
      format: 'html',
      linenum: true
    )
    assert_not_equal(body, result)
    assert_match(/table.*highlight.*rouge-table/, result)
  end

  def test_highlight_with_custom_options
    config = { 'highlight' => { 'html' => 'rouge' } }
    highlighter = ReVIEW::Highlighter.new(config)

    body = 'puts "hello world"'

    result = highlighter.highlight(
      body: body,
      lexer: 'ruby',
      format: 'html',
      options: { linenostart: 10, style: 'github' }
    )
    assert_not_equal(body, result)
  end

  def test_rouge_html_highlighting_ruby_code
    config = { 'highlight' => { 'html' => 'rouge' } }
    highlighter = ReVIEW::Highlighter.new(config)

    ruby_code = 'puts "Hello, World!"'
    result = highlighter.highlight(body: ruby_code, lexer: 'ruby', format: 'html')

    assert_match(/<span\s+class=".*">/, result)
  end

  def test_rouge_html_highlighting_with_line_numbers
    config = { 'highlight' => { 'html' => 'rouge' } }
    highlighter = ReVIEW::Highlighter.new(config)

    code = "def hello\n  puts \"Hello\"\nend"
    result = highlighter.highlight(
      body: code,
      lexer: 'ruby',
      format: 'html',
      linenum: true
    )

    assert_match(/<table class=".*rouge-table.*">/, result)
    assert_match(/rouge-gutter/, result)
    assert_match(/rouge-code/, result)
  end

  def test_rouge_html_highlighting_with_custom_start_line
    config = { 'highlight' => { 'html' => 'rouge' } }
    highlighter = ReVIEW::Highlighter.new(config)

    code = "x = 1\ny = 2"
    result = highlighter.highlight(
      body: code,
      lexer: 'ruby',
      format: 'html',
      linenum: true,
      options: { linenostart: 10 }
    )

    assert_match(/<table class=".*rouge-table.*">/, result)
    assert_match(/<pre class="lineno">10\n11\n/, result)
  end

  def test_pygments_html_highlighting_ruby_code
    config = { 'highlight' => { 'html' => 'pygments' } }
    highlighter = ReVIEW::Highlighter.new(config)

    skip('Pygments gem not available') unless highlighter.pygments_available?

    ruby_code = 'class Test; end'
    result = highlighter.highlight(body: ruby_code, lexer: 'ruby', format: 'html')

    assert_match(/<span style="color:.*">/, result)
  end

  def test_pygments_html_highlighting_with_line_numbers
    config = { 'highlight' => { 'html' => 'pygments' } }
    highlighter = ReVIEW::Highlighter.new(config)

    skip('Pygments gem not available') unless highlighter.pygments_available?

    code = "def method\n  return true\nend"
    result = highlighter.highlight(
      body: code,
      lexer: 'ruby',
      format: 'html',
      linenum: true
    )

    assert_match(/style=/, result)
  end
end
