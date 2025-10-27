# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/inline_processor'
require 'review/ast/compiler'
require 'review/configure'
require 'review/book'
require 'review/book/chapter'
require 'review/location'

class TestInlineProcessorComprehensive < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])

    # Create mock AST compiler for InlineProcessor
    @ast_compiler = ReVIEW::AST::Compiler.new
    # Create a default location with proper file object
    file_mock = StringIO.new('test content')
    file_mock.lineno = 1
    default_location = ReVIEW::Location.new('test.re', file_mock)
    @ast_compiler.force_override_location!(default_location)
    @processor = ReVIEW::AST::InlineProcessor.new(@ast_compiler)
  end

  # Simple test cases (2)
  def test_simple_text_only
    file_mock = StringIO.new('test content')
    file_mock.lineno = 1
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', file_mock)
    )

    @processor.parse_inline_elements('Hello world', parent)

    assert_equal 1, parent.children.size
    text_node = parent.children.first
    assert_instance_of(ReVIEW::AST::TextNode, text_node)
    assert_equal 'Hello world', text_node.content
  end

  def test_simple_single_inline
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('This is @<b>{bold} text', parent)

    assert_equal 3, parent.children.size

    # First: text before
    assert_instance_of(ReVIEW::AST::TextNode, parent.children[0])
    assert_equal 'This is ', parent.children[0].content

    # Second: inline element
    assert_instance_of(ReVIEW::AST::InlineNode, parent.children[1])
    assert_equal :b, parent.children[1].inline_type
    assert_equal ['bold'], parent.children[1].args

    # Third: text after
    assert_instance_of(ReVIEW::AST::TextNode, parent.children[2])
    assert_equal ' text', parent.children[2].content
  end

  # Complex test cases (10) - Some may fail with current implementation but represent expected behavior
  def test_multiple_consecutive_inlines
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('Start @<b>{bold}@<i>{italic}@<code>{code} end', parent)

    # Expected behavior: should parse all three consecutive inline elements
    assert_equal 5, parent.children.size
    assert_equal 'Start ', parent.children[0].content
    assert_equal :b, parent.children[1].inline_type
    assert_equal :i, parent.children[2].inline_type
    assert_equal :code, parent.children[3].inline_type
    assert_equal ' end', parent.children[4].content
  end

  def test_nested_inline_elements
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('Text @<b>{bold with @<i>{nested italic\}} more', parent)
    # Expected behavior: should handle nested inline elements correctly
    assert_equal 3, parent.children.size
    assert_equal 'Text ', parent.children[0].content

    # Bold inline with nested content
    bold_node = parent.children[1]
    assert_equal :b, bold_node.inline_type
    assert_equal 2, bold_node.children.size
    assert_equal 'bold with ', bold_node.children[0].content
    assert_equal :i, bold_node.children[1].inline_type
    assert_equal 'nested italic', bold_node.children[1].children[0].content

    assert_equal ' more', parent.children[2].content
  end

  def test_ruby_inline_format
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('Text @<ruby>{漢字, かんじ} more', parent)

    assert_equal 3, parent.children.size
    ruby_node = parent.children[1]
    assert_equal :ruby, ruby_node.inline_type
    assert_equal ['漢字', 'かんじ'], ruby_node.args
    assert_equal 2, ruby_node.children.size
    assert_equal '漢字', ruby_node.children[0].content
    assert_equal 'かんじ', ruby_node.children[1].content
  end

  def test_href_inline_format
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('Visit @<href>{https://example.com, Example Site} for info', parent)

    assert_equal 3, parent.children.size
    href_node = parent.children[1]
    assert_equal :href, href_node.inline_type
    assert_equal ['https://example.com', 'Example Site'], href_node.args
    assert_equal 1, href_node.children.size
    assert_equal 'Example Site', href_node.children[0].content
  end

  def test_href_url_only_format
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('Visit @<href>{https://example.com} directly', parent)

    assert_equal 3, parent.children.size
    href_node = parent.children[1]
    assert_equal :href, href_node.inline_type
    assert_equal ['https://example.com'], href_node.args
    assert_equal 1, href_node.children.size
    assert_equal 'https://example.com', href_node.children[0].content
  end

  def test_kw_inline_format
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('See @<kw>{API, Application Programming Interface} docs', parent)

    assert_equal 3, parent.children.size
    kw_node = parent.children[1]
    assert_equal :kw, kw_node.inline_type
    assert_equal ['API', 'Application Programming Interface'], kw_node.args
    assert_equal 2, kw_node.children.size
    assert_equal 'API', kw_node.children[0].content
    assert_equal 'Application Programming Interface', kw_node.children[1].content
  end

  def test_hd_inline_format
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('Refer to @<hd>{chapter1|Introduction} section', parent)

    assert_equal 3, parent.children.size
    hd_node = parent.children[1]
    assert_equal :hd, hd_node.inline_type
    assert_equal ['chapter1', 'Introduction'], hd_node.args
    assert_equal 1, hd_node.children.size

    reference_node = hd_node.children[0]
    assert_equal 'Introduction', reference_node.ref_id
    assert_equal 'chapter1', reference_node.context_id
    assert_equal 'chapter1|Introduction', reference_node.content
  end

  def test_reference_inline_elements
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('See @<img>{figure1} and @<list>{code1} and @<table>{data1}', parent)

    assert_equal 6, parent.children.size
    assert_equal 'See ', parent.children[0].content

    img_node = parent.children[1]
    assert_equal :img, img_node.inline_type
    assert_equal ['figure1'], img_node.args

    assert_equal ' and ', parent.children[2].content

    list_node = parent.children[3]
    assert_equal :list, list_node.inline_type
    assert_equal ['code1'], list_node.args

    assert_equal ' and ', parent.children[4].content

    table_node = parent.children[5]
    assert_equal :table, table_node.inline_type
    assert_equal ['data1'], table_node.args
  end

  def test_cross_reference_inline_elements
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('See @<chap>{intro} and @<sec>{overview} for details', parent)

    assert_equal 5, parent.children.size
    assert_equal 'See ', parent.children[0].content

    chap_node = parent.children[1]
    assert_equal :chap, chap_node.inline_type
    assert_equal ['intro'], chap_node.args

    assert_equal ' and ', parent.children[2].content

    sec_node = parent.children[3]
    assert_equal :sec, sec_node.inline_type
    assert_equal ['overview'], sec_node.args

    assert_equal ' for details', parent.children[4].content
  end

  def test_fence_syntax_elements
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Test both dollar and pipe fence syntax
    @processor.parse_inline_elements('Code: @<code>$puts "hello"$ and math: @<m>|x^2 + y^2|.', parent)

    # Expected behavior: should parse fence syntax correctly
    assert_equal 5, parent.children.size
    assert_equal 'Code: ', parent.children[0].content

    code_node = parent.children[1]
    assert_equal :code, code_node.inline_type
    assert_equal ['puts "hello"'], code_node.args

    assert_equal ' and math: ', parent.children[2].content

    math_node = parent.children[3]
    assert_equal :m, math_node.inline_type
    assert_equal ['x^2 + y^2'], math_node.args
    assert_equal '.', parent.children[4].content
  end

  def test_escaped_characters_in_inline
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('Code @<code>{func\\\\{param\\\\\}} example', parent)

    assert_equal 3, parent.children.size
    assert_equal 'Code ', parent.children[0].content

    code_node = parent.children[1]
    assert_equal :code, code_node.inline_type
    assert_equal ['func\\{param\\}'], code_node.args
    assert_equal 1, code_node.children.size
    assert_equal 'func\\{param\\}', code_node.children[0].content

    assert_equal ' example', parent.children[2].content
  end

  def test_complex_nested_with_multiple_types
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('Start @<b>{bold @<code>{nested code\} and @<i>{italic\}} end', parent)

    # Expected behavior: should handle complex nested structures
    assert_equal 3, parent.children.size
    assert_equal 'Start ', parent.children[0].content

    bold_node = parent.children[1]
    assert_equal :b, bold_node.inline_type
    assert_equal 4, bold_node.children.size
    assert_equal 'bold ', bold_node.children[0].content
    assert_equal :code, bold_node.children[1].inline_type
    assert_equal ' and ', bold_node.children[2].content
    assert_equal :i, bold_node.children[3].inline_type

    assert_equal ' end', parent.children[2].content
  end

  # Edge cases and error handling
  def test_empty_string
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('', parent)

    assert_equal 0, parent.children.size
  end

  def test_malformed_inline_element
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Unclosed brace should cause an InlineTokenizeError
    assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements('Bad @<b>{unclosed text', parent)
    end
  end

  def test_malformed_fence_syntax
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Unclosed fence should cause an InlineTokenizeError
    assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements('Code @<code>$unclosed fence', parent)
    end
  end

  def test_inline_with_special_characters
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('Math @<m>{∑_{i=1\}^n x_i} formula', parent)

    assert_equal 3, parent.children.size
    assert_equal 'Math ', parent.children[0].content

    math_node = parent.children[1]
    assert_equal :m, math_node.inline_type
    assert_equal ['∑_{i=1}^n x_i'], math_node.args

    assert_equal ' formula', parent.children[2].content
  end

  def test_inline_with_line_breaks
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Line breaks within inline elements should cause an InlineTokenizeError
    assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements("Text @<b>{bold\ntext} more", parent)
    end
  end

  def test_multiple_ruby_elements
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('日本語 @<ruby>{漢字, かんじ} and @<ruby>{平仮名, ひらがな} text', parent)

    assert_equal 5, parent.children.size
    assert_equal '日本語 ', parent.children[0].content

    ruby1 = parent.children[1]
    assert_equal :ruby, ruby1.inline_type
    assert_equal ['漢字', 'かんじ'], ruby1.args

    assert_equal ' and ', parent.children[2].content

    ruby2 = parent.children[3]
    assert_equal :ruby, ruby2.inline_type
    assert_equal ['平仮名', 'ひらがな'], ruby2.args

    assert_equal ' text', parent.children[4].content
  end

  def test_inline_with_empty_content
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    @processor.parse_inline_elements('Empty @<b>{} content', parent)

    assert_equal 3, parent.children.size
    assert_equal 'Empty ', parent.children[0].content

    bold_node = parent.children[1]
    assert_equal :b, bold_node.inline_type
    assert_equal [''], bold_node.args

    assert_equal ' content', parent.children[2].content
  end

  def test_invalid_command_name_with_numbers
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Command names starting with numbers should cause an error
    assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements('Invalid @<123>{content} command', parent)
    end
  end

  def test_invalid_command_name_with_uppercase
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Command names with uppercase letters should cause an error
    assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements('Invalid @<Bold>{content} command', parent)
    end
  end

  def test_invalid_command_name_with_symbols
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Command names with symbols should cause an error
    assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements('Invalid @<b-old>{content} command', parent)
    end
  end

  def test_invalid_command_name_with_underscore
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Command names with underscores should cause an error
    assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements('Invalid @<code_block>{content} command', parent)
    end
  end

  def test_invalid_command_name_empty
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Empty command names should cause an error
    assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements('Invalid @<>{content} command', parent)
    end
  end

  def test_nested_fence_syntax_conflict
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Nested fence syntax should cause an error for clarity
    assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements('Code @<code>$outer @<m>|inner| text$ end', parent)
    end
  end

  # Error message tests - verify that error messages contain useful information
  def test_unclosed_brace_error_message
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Create a location for error context
    file_mock = StringIO.new('test content')
    file_mock.lineno = 42
    location = ReVIEW::Location.new('sample.re', file_mock)
    @ast_compiler.force_override_location!(location)

    error = assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements('Text @<b>{unclosed brace content', parent)
    end

    # Verify error message contains expected information
    assert_match(/Unclosed inline element braces/, error.message)
    assert_match(/in element: @<b>\{unclosed brace content/, error.message)
    assert_match(/at line 42/, error.message)
    assert_match(/in sample\.re/, error.message)
  end

  def test_line_break_in_brace_error_message
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Create a location for error context
    file_mock = StringIO.new('test content')
    file_mock.lineno = 15
    location = ReVIEW::Location.new('chapter01.re', file_mock)
    @ast_compiler.force_override_location!(location)

    error = assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements("Text @<b>{content with\nline break}", parent)
    end

    # Verify error message contains expected information
    assert_match(/Line breaks are not allowed within inline elements/, error.message)
    assert_match(/in element: @<b>\{content with/, error.message)
    assert_match(/at line 15/, error.message)
    assert_match(/in chapter01\.re/, error.message)
  end

  def test_unclosed_fence_error_message
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Create a location for error context
    file_mock = StringIO.new('test content')
    file_mock.lineno = 99
    location = ReVIEW::Location.new('appendix.re', file_mock)
    @ast_compiler.force_override_location!(location)

    error = assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements('Code @<tt>$unclosed fence content', parent)
    end

    # Verify error message contains expected information
    assert_match(/Unclosed inline element fence/, error.message)
    assert_match(/in element: @<tt>\$unclosed fence content/, error.message)
    assert_match(/at line 99/, error.message)
    assert_match(/in appendix\.re/, error.message)
  end

  def test_line_break_in_fence_error_message
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Create a location for error context
    file_mock = StringIO.new('test content')
    file_mock.lineno = 7
    location = ReVIEW::Location.new('intro.re', file_mock)
    @ast_compiler.force_override_location!(location)

    error = assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements("Code @<tt>$content with\nline break$", parent)
    end

    # Verify error message contains expected information
    assert_match(/Line breaks are not allowed within inline elements/, error.message)
    assert_match(/in element: @<tt>\$content with/, error.message)
    assert_match(/at line 7/, error.message)
    assert_match(/in intro\.re/, error.message)
  end

  def test_invalid_command_name_error_message
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Create a location for error context
    file_mock = StringIO.new('test content')
    file_mock.lineno = 33
    location = ReVIEW::Location.new('references.re', file_mock)
    @ast_compiler.force_override_location!(location)

    error = assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements('Invalid @<B0LD>{content} command', parent)
    end

    # Verify error message contains expected information
    assert_match(/Invalid command name 'B0LD'/, error.message)
    assert_match(/only ASCII lowercase letters are allowed/, error.message)
  end

  def test_nested_fence_syntax_error_message
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Create a location for error context
    file_mock = StringIO.new('test content')
    file_mock.lineno = 55
    location = ReVIEW::Location.new('complex.re', file_mock)
    @ast_compiler.force_override_location!(location)

    error = assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements('Code @<code>$outer @<m>|inner| text$ end', parent)
    end

    # Verify error message contains expected information
    assert_match(/Nested inline elements within fence syntax are not allowed/, error.message)
    assert_match(/in element: @<code>\$outer @<m>\|inner\| text\$/, error.message)
    assert_match(/at line 55/, error.message)
    assert_match(/in complex\.re/, error.message)
  end

  def test_error_message_without_location_info
    parent = ReVIEW::AST::ParagraphNode.new(
      location: ReVIEW::Location.new('test.re', 1)
    )

    # Set location to nil to test error messages without location context
    @ast_compiler.force_override_location!(nil)

    error = assert_raises(ReVIEW::AST::InlineTokenizeError) do
      @processor.parse_inline_elements('Text @<b>{unclosed content', parent)
    end

    # Verify error message contains element info but no location info
    assert_match(/Unclosed inline element braces/, error.message)
    assert_match(/in element: @<b>\{unclosed content/, error.message)
    refute_match(/at line/, error.message)
    refute_match(/in .*\.re/, error.message)
  end
end
