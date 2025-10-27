# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/compiler'
require 'review/ast/list_processor'
require 'review/configure'
require 'review/book'
require 'review/i18n'

class TestListProcessorError < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new(config: @config)
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_unknown_list_type_error_with_location
    content = "= Chapter\n\nSome content here"

    chapter = ReVIEW::Book::Chapter.new(
      @book,
      1,
      'test',
      'unknown_list.re',
      StringIO.new(content)
    )

    compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
    processor = ReVIEW::AST::ListProcessor.new(compiler)

    # Create a mock LineInput at line 3
    line_input = ReVIEW::LineInput.new(StringIO.new('dummy content'))

    # Set location manually for testing
    mock_file = StringIO.new(content)
    mock_file.define_singleton_method(:lineno) { 3 }
    location = ReVIEW::Location.new('unknown_list.re', mock_file)
    compiler.force_override_location!(location)

    error = assert_raises(ReVIEW::CompileError) do
      processor.process_list(line_input, :unknown_list_type)
    end

    assert_match(/Unknown list type: unknown_list_type/, error.message)
    assert_match(/at line 3/, error.message)
    assert_match(/in unknown_list\.re/, error.message)
  end

  def test_parse_list_items_with_unknown_type
    content = "= Chapter\n\n * item1\n * item2"

    chapter = ReVIEW::Book::Chapter.new(
      @book,
      1,
      'test',
      'fallback_test.re',
      StringIO.new(content)
    )

    compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
    processor = ReVIEW::AST::ListProcessor.new(compiler)

    # Create a LineInput with list content
    list_content = " * item1\n * item2\n"
    line_input = ReVIEW::LineInput.new(StringIO.new(list_content))

    assert_raises(ReVIEW::CompileError) do
      processor.parse_list_items(line_input, :custom_list)
    end
  end
end
