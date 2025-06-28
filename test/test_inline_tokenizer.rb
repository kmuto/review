# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast/inline_tokenizer'

class TestInlineTokenizer < Test::Unit::TestCase
  def setup
    @tokenizer = ReVIEW::AST::InlineTokenizer.new
  end

  def test_simple_text
    tokens = @tokenizer.tokenize('Hello world')

    assert_equal 1, tokens.length
    assert_equal :text, tokens[0][:type]
    assert_equal 'Hello world', tokens[0][:content]
  end

  def test_simple_inline_element
    tokens = @tokenizer.tokenize('This is @<b>{bold} text')

    assert_equal 3, tokens.length

    # First token: text before inline element
    assert_equal :text, tokens[0][:type]
    assert_equal 'This is ', tokens[0][:content]

    # Second token: inline element
    assert_equal :inline, tokens[1][:type]
    assert_equal 'b', tokens[1][:command]
    assert_equal 'bold', tokens[1][:content]

    # Third token: text after inline element
    assert_equal :text, tokens[2][:type]
    assert_equal ' text', tokens[2][:content]
  end

  def test_fence_syntax_dollar
    tokens = @tokenizer.tokenize('Code: @<code>$puts "hello"$')

    assert_equal 2, tokens.length

    assert_equal :text, tokens[0][:type]
    assert_equal 'Code: ', tokens[0][:content]

    assert_equal :inline, tokens[1][:type]
    assert_equal 'code', tokens[1][:command]
    assert_equal 'puts "hello"', tokens[1][:content]
  end

  def test_fence_syntax_pipe
    tokens = @tokenizer.tokenize('Math: @<m>|x^2 + y^2|')

    assert_equal 2, tokens.length

    assert_equal :text, tokens[0][:type]
    assert_equal 'Math: ', tokens[0][:content]

    assert_equal :inline, tokens[1][:type]
    assert_equal 'm', tokens[1][:command]
    assert_equal 'x^2 + y^2', tokens[1][:content]
  end

  def test_escaped_braces
    tokens = @tokenizer.tokenize('Test @<code>{func\\{\\}} end')

    assert_equal 3, tokens.length

    assert_equal :text, tokens[0][:type]
    assert_equal 'Test ', tokens[0][:content]

    assert_equal :inline, tokens[1][:type]
    assert_equal 'code', tokens[1][:command]
    assert_equal 'func\\{\\}', tokens[1][:content]

    assert_equal :text, tokens[2][:type]
    assert_equal ' end', tokens[2][:content]
  end

  def test_nested_braces
    tokens = @tokenizer.tokenize('Example @<ruby>{base{sub}, ruby} text')

    assert_equal 3, tokens.length

    assert_equal :text, tokens[0][:type]
    assert_equal 'Example ', tokens[0][:content]

    assert_equal :inline, tokens[1][:type]
    assert_equal 'ruby', tokens[1][:command]
    assert_equal 'base{sub}, ruby', tokens[1][:content]

    assert_equal :text, tokens[2][:type]
    assert_equal ' text', tokens[2][:content]
  end

  def test_multiple_inline_elements
    tokens = @tokenizer.tokenize('This @<b>{bold} and @<i>{italic} text')

    assert_equal 5, tokens.length

    assert_equal :text, tokens[0][:type]
    assert_equal 'This ', tokens[0][:content]

    assert_equal :inline, tokens[1][:type]
    assert_equal 'b', tokens[1][:command]
    assert_equal 'bold', tokens[1][:content]

    assert_equal :text, tokens[2][:type]
    assert_equal ' and ', tokens[2][:content]

    assert_equal :inline, tokens[3][:type]
    assert_equal 'i', tokens[3][:command]
    assert_equal 'italic', tokens[3][:content]

    assert_equal :text, tokens[4][:type]
    assert_equal ' text', tokens[4][:content]
  end

  def test_malformed_inline_element
    # Unclosed brace should be treated as separate text tokens
    tokens = @tokenizer.tokenize('Bad @<b>{unclosed text')

    assert_equal 3, tokens.length

    assert_equal :text, tokens[0][:type]
    assert_equal 'Bad ', tokens[0][:content]

    assert_equal :text, tokens[1][:type]
    assert_equal '@<b>{', tokens[1][:content]

    assert_equal :text, tokens[2][:type]
    assert_equal 'unclosed text', tokens[2][:content]
  end

  def test_empty_string
    tokens = @tokenizer.tokenize('')
    assert_equal 0, tokens.length
  end

  def test_only_inline_element
    tokens = @tokenizer.tokenize('@<b>{bold}')

    assert_equal 1, tokens.length
    assert_equal :inline, tokens[0][:type]
    assert_equal 'b', tokens[0][:command]
    assert_equal 'bold', tokens[0][:content]
  end
end
