# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/compiler'
require 'review/configure'
require 'review/book'
require 'review/i18n'

class TestCompilerErrorMessages < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_max_headline_level_error_with_location
    content = "= Chapter\n\n======= Too Deep Headline"

    chapter = ReVIEW::Book::Chapter.new(
      @book,
      1,
      'test',
      'deep_headline.re',
      StringIO.new(content)
    )

    error = assert_raises(ReVIEW::CompileError) do
      compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
      compiler.compile_to_ast(chapter)
    end

    # Verify error message contains expected information
    assert_match(/Invalid header: max headline level is 6/, error.message)
    assert_match(/at line 3/, error.message)
    assert_match(/in deep_headline\.re/, error.message)
  end

  def test_unknown_block_command_with_location
    content = "= Chapter\n\n//unknowncommand{\ncontent\n//}"

    chapter = ReVIEW::Book::Chapter.new(
      @book,
      1,
      'test',
      'unknown_command.re',
      StringIO.new(content)
    )

    error = assert_raises(ReVIEW::CompileError) do
      compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
      compiler.compile_to_ast(chapter)
    end

    # Verify error message contains expected information
    assert_match(%r{Unknown block command: //unknowncommand}, error.message)
    assert_match(/at line/, error.message)
    assert_match(/in unknown_command\.re/, error.message)
  end
end
