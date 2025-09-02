# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/inline_tokenizer'
require 'review/ast/inline_processor'
require 'review/ast/compiler'
require 'review/configure'
require 'review/book'
require 'review/i18n'

class TestInlineBraceEscape < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['language'] = 'ja'
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])

    @tokenizer = ReVIEW::AST::InlineTokenizer.new
  end

  def test_simple_brace_escape
    # Test basic \} escape
    tokens = @tokenizer.tokenize('@<b>{test \\} content}')

    assert_equal 1, tokens.size
    token = tokens[0]
    assert_equal :inline, token.type
    assert_equal 'b', token.command
    assert_equal 'test } content', token.content
  end

  def test_multiple_brace_escapes
    # Test multiple escaped braces
    tokens = @tokenizer.tokenize('@<code>{if (x \\} y) \\{ print "hello \\}" \\}}')

    assert_equal 1, tokens.size
    token = tokens[0]
    assert_equal :inline, token.type
    assert_equal 'code', token.command
    assert_equal 'if (x } y) \\{ print "hello }" }', token.content
  end

  def test_mixed_escaped_and_nested_braces
    # Test combination of escaped braces - with new rules, first unescaped } terminates
    tokens = @tokenizer.tokenize('@<b>{outer \\{nested \\} content\\} more}')

    assert_equal 1, tokens.size
    token = tokens[0]
    assert_equal :inline, token.type
    assert_equal 'b', token.command
    assert_equal 'outer \\{nested } content} more', token.content
  end

  def test_escape_at_end
    # Test escaped brace at the end of content
    tokens = @tokenizer.tokenize('@<code>{JSON.parse("\\{\\"key\\": \\"value\\"\\}")}')

    assert_equal 1, tokens.size
    token = tokens[0]
    assert_equal :inline, token.type
    assert_equal 'code', token.command
    # All escaped braces become regular braces, other backslashes preserved
    assert_equal 'JSON.parse("\\{\\"key\\": \\"value\\"}")', token.content
  end

  def test_backslash_not_followed_by_brace
    # Test that backslashes not followed by } are preserved
    tokens = @tokenizer.tokenize('@<code>{\\n \\t \\\\}')

    assert_equal 1, tokens.size
    token = tokens[0]
    assert_equal :inline, token.type
    assert_equal 'code', token.command
    assert_equal '\\n \\t \\', token.content
  end

  def test_mixed_content_with_escape
    # Test inline element in mixed content
    tokens = @tokenizer.tokenize('Before @<b>{bold \\} text} after')

    assert_equal 3, tokens.size

    # First token: text before
    assert_equal :text, tokens[0].type
    assert_equal 'Before ', tokens[0].content

    # Second token: inline element with escaped brace
    assert_equal :inline, tokens[1].type
    assert_equal 'b', tokens[1].command
    assert_equal 'bold } text', tokens[1].content

    # Third token: text after
    assert_equal :text, tokens[2].type
    assert_equal ' after', tokens[2].content
  end

  def test_backslash_escape
    # Test basic \\ escape
    tokens = @tokenizer.tokenize('@<code>{path\\\\file.txt}')

    assert_equal 1, tokens.size
    token = tokens[0]
    assert_equal :inline, token.type
    assert_equal 'code', token.command
    assert_equal 'path\\file.txt', token.content
  end

  def test_at_sign_escape
    # Test basic \@ escape
    tokens = @tokenizer.tokenize('@<code>{email\\@example.com}')

    assert_equal 1, tokens.size
    token = tokens[0]
    assert_equal :inline, token.type
    assert_equal 'code', token.command
    assert_equal 'email@example.com', token.content
  end

  def test_multiple_escape_types
    # Test all escape types together
    tokens = @tokenizer.tokenize('@<code>{obj\\@method(param\\} result)}')

    assert_equal 1, tokens.size
    token = tokens[0]
    assert_equal :inline, token.type
    assert_equal 'code', token.command
    assert_equal 'obj@method(param} result)', token.content
  end

  def test_consecutive_escapes
    # Test consecutive escaped characters
    tokens = @tokenizer.tokenize('@<code>{\\\\\\@ and \\}\\\\}')

    assert_equal 1, tokens.size
    token = tokens[0]
    assert_equal :inline, token.type
    assert_equal 'code', token.command
    assert_equal '\\@ and }\\', token.content
  end

  def test_end_to_end_with_ast_compiler
    # Test that escaped braces work through the entire AST compilation process
    content = "= Test Chapter\n\nThis is @<b>{bold with \\} escaped brace} text."

    chapter = ReVIEW::Book::Chapter.new(
      @book,
      1,
      'test',
      'escape_test.re',
      StringIO.new(content)
    )

    compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
    ast_root = compiler.compile_to_ast(chapter)

    # Find the paragraph node
    paragraph = ast_root.children.find { |child| child.class.name.include?('Paragraph') }
    assert_not_nil(paragraph)

    # Find the inline element in the paragraph
    inline_element = nil
    paragraph.children.each do |child|
      if child.class.name.include?('Inline') && child.inline_type == 'b'
        inline_element = child
        break
      end
    end

    assert_not_nil(inline_element)
    # The content should have the escaped brace converted to a plain brace
    text_content = inline_element.children.map(&:content).join
    assert_equal 'bold with } escaped brace', text_content
  end

  def test_end_to_end_with_all_escapes
    # Test all escape types through the entire AST compilation process
    content = "= Test Chapter\n\nExample: @<code>{func\\@host(path\\\\file, param\\})} works."

    chapter = ReVIEW::Book::Chapter.new(
      @book,
      1,
      'test',
      'all_escape_test.re',
      StringIO.new(content)
    )

    compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
    ast_root = compiler.compile_to_ast(chapter)

    # Find the paragraph node
    paragraph = ast_root.children.find { |child| child.class.name.include?('Paragraph') }
    assert_not_nil(paragraph)

    # Find the inline element in the paragraph
    inline_element = nil
    paragraph.children.each do |child|
      if child.class.name.include?('Inline') && child.inline_type == 'code'
        inline_element = child
        break
      end
    end

    assert_not_nil(inline_element)
    # The content should have all escapes converted properly
    text_content = inline_element.children.map(&:content).join
    assert_equal 'func@host(path\\file, param})', text_content
  end
end
