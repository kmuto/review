# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/html_diff'

class ASTHTMLDiffTest < Test::Unit::TestCase
  def test_same_html_same_hash
    html1 = '<p>Hello World</p>'
    html2 = '<p>Hello World</p>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_different_html_different_hash
    html1 = '<p>Hello World</p>'
    html2 = '<p>Hello World!</p>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_false(diff.same_hash?)
  end

  def test_whitespace_normalized
    html1 = '<p>Hello    World</p>'
    html2 = '<p>Hello World</p>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_whitespace_preserved_in_pre
    html1 = '<pre>Hello    World</pre>'
    html2 = '<pre>Hello World</pre>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_false(diff.same_hash?)
  end

  def test_comments_removed
    # Comments are removed but text nodes remain separate
    html1 = '<p>Hello</p><!-- comment --><p>World</p>'
    html2 = '<p>Hello</p><p>World</p>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_class_attribute_sorted
    html1 = '<div class="foo bar baz">test</div>'
    html2 = '<div class="baz foo bar">test</div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_class_attribute_duplicates_removed
    html1 = '<div class="foo bar foo baz">test</div>'
    html2 = '<div class="bar baz foo">test</div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_empty_class_removed
    html1 = '<div class="">test</div>'
    html2 = '<div>test</div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_attribute_names_lowercased
    html1 = '<div ID="test">content</div>'
    html2 = '<div id="test">content</div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_void_elements
    html1 = '<p>Line 1<br>Line 2</p>'
    html2 = '<p>Line 1<br/>Line 2</p>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_img_void_element
    html1 = '<img src="test.png" alt="test">'
    html2 = '<img src="test.png" alt="test"/>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_diff_tokens_same_content
    html1 = '<p>Hello</p>'
    html2 = '<p>Hello</p>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    changes = diff.diff_tokens
    assert_equal(0, changes.count { |c| c.action != '=' })
  end

  def test_diff_tokens_text_changed
    html1 = '<p>Hello</p>'
    html2 = '<p>Goodbye</p>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    changes = diff.diff_tokens
    assert(changes.any? { |c| c.action == '!' })
  end

  def test_diff_tokens_element_added
    html1 = '<p>Hello</p>'
    html2 = '<p>Hello</p><p>World</p>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    changes = diff.diff_tokens
    assert(changes.any? { |c| c.action == '+' })
  end

  def test_diff_tokens_element_removed
    html1 = '<p>Hello</p><p>World</p>'
    html2 = '<p>Hello</p>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    changes = diff.diff_tokens
    assert(changes.any? { |c| c.action == '-' })
  end

  def test_pretty_diff_no_changes
    html1 = '<p>Hello</p>'
    html2 = '<p>Hello</p>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    pretty = diff.pretty_diff
    assert_equal '', pretty
  end

  def test_pretty_diff_with_changes
    html1 = '<p>Hello</p>'
    html2 = '<p>Goodbye</p>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    pretty = diff.pretty_diff
    assert pretty.include?('Hello')
    assert pretty.include?('Goodbye')
    assert pretty.include?('-')
    assert pretty.include?('+')
  end

  def test_complex_html_structure
    html1 = <<~HTML
      <div class="container">
        <h1>Title</h1>
        <p>Paragraph 1</p>
        <ul>
          <li>Item 1</li>
          <li>Item 2</li>
        </ul>
      </div>
    HTML

    html2 = <<~HTML
      <div class="container">
        <h1>Title</h1>
        <p>Paragraph 1</p>
        <ul>
          <li>Item 1</li>
          <li>Item 2</li>
        </ul>
      </div>
    HTML

    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_nested_elements_with_attributes
    html1 = '<div id="outer" class="wrapper"><span class="inner" data-value="123">Text</span></div>'
    html2 = '<div class="wrapper" id="outer"><span data-value="123" class="inner">Text</span></div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_significant_whitespace_in_textarea
    html1 = '<textarea>Line 1\n  Line 2\n    Line 3</textarea>'
    html2 = '<textarea>Line 1\nLine 2\nLine 3</textarea>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_false(diff.same_hash?)
  end

  def test_significant_whitespace_in_script
    html1 = '<script>var x = 1;  var y = 2;</script>'
    html2 = '<script>var x = 1; var y = 2;</script>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_false(diff.same_hash?)
  end

  def test_significant_whitespace_in_style
    html1 = '<style>body { margin: 0;  padding: 0; }</style>'
    html2 = '<style>body { margin: 0; padding: 0; }</style>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_false(diff.same_hash?)
  end

  def test_mixed_content
    html1 = '<div>Text before <strong>bold text</strong> text after</div>'
    html2 = '<div>Text before <strong>bold text</strong> text after</div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_empty_text_nodes_removed
    html1 = '<div>  <span>Text</span>  </div>'
    html2 = '<div><span>Text</span></div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_multiple_void_elements
    html1 = '<div><br><hr><img src="test.png"></div>'
    html2 = '<div><br/><hr/><img src="test.png"/></div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_attribute_order_normalized
    html1 = '<div data-id="1" class="test" id="main">Content</div>'
    html2 = '<div id="main" class="test" data-id="1">Content</div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_real_world_example_article
    html1 = <<~HTML
      <article>
        <header>
          <h1 class="title">My Article</h1>
          <p class="meta">
            Published on 2024-01-01
          </p>
        </header>
        <section>
          <p>
            First paragraph.
          </p>
          <p>
            Second paragraph with
            <a href="link.html">a link</a>
            .
          </p>
        </section>
      </article>
    HTML

    html2 = <<~HTML
      <article>
        <header>
        <h1 class="title">My Article</h1>
        <p class="meta">Published on 2024-01-01</p>
        </header>
        <section>
          <p>First paragraph.</p><p>Second paragraph with <a href="link.html">a link</a>.</p>
        </section>
      </article>
    HTML

    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_real_world_example_with_difference
    html1 = <<~HTML
      <article>
        <h1>Title</h1>
        <p>Original text.</p>
      </article>
    HTML

    html2 = <<~HTML
      <article>
        <h1>Title</h1>
        <p>Modified text.</p>
      </article>
    HTML

    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_false(diff.same_hash?)
    pretty = diff.pretty_diff
    assert pretty.include?('Original')
    assert pretty.include?('Modified')
  end

  def test_newlines_normalized
    html1 = "<p>\n\n\nHello\n\n\nWorld\n\n\n</p>"
    html2 = '<p>Hello World</p>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_tabs_normalized
    html1 = "<p>Hello\t\t\tWorld</p>"
    html2 = '<p>Hello World</p>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_leading_trailing_whitespace
    html1 = '<p>   Hello World   </p>'
    html2 = '<p>Hello World</p>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_multiple_classes_with_whitespace
    html1 = '<div class="  foo   bar   baz  ">test</div>'
    html2 = '<div class="bar baz foo">test</div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_nested_void_elements
    html1 = '<div><p>Text<br>More<br>Lines</p></div>'
    html2 = '<div><p>Text<br/>More<br/>Lines</p></div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_empty_attributes
    html1 = '<input type="text" disabled>'
    html2 = '<input disabled type="text">'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_multiple_attributes_sorted
    html1 = '<div z="3" y="2" x="1" class="foo" id="main">test</div>'
    html2 = '<div class="foo" id="main" x="1" y="2" z="3">test</div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_deeply_nested_structure
    html1 = '<div><section><article><p><span>Text</span></p></article></section></div>'
    html2 = '<div><section><article><p><span>Text</span></p></article></section></div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_self_closing_void_element_formats
    html1 = '<meta charset="utf-8"><link rel="stylesheet" href="style.css">'
    html2 = '<meta charset="utf-8"/><link rel="stylesheet" href="style.css"/>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_mixed_significant_whitespace
    html1 = '<div><pre>  code  </pre><p>  text  </p></div>'
    html2 = '<div><pre>  code  </pre><p>text</p></div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_data_attributes
    html1 = '<div data-id="123" data-name="test">Content</div>'
    html2 = '<div data-name="test" data-id="123">Content</div>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_complex_class_normalization
    html1 = '<span class="a  b  a  c  b  d">text</span>'
    html2 = '<span class="a b c d">text</span>'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end

  def test_boolean_attributes
    html1 = '<input type="checkbox" checked disabled readonly>'
    html2 = '<input checked disabled readonly type="checkbox">'
    diff = ReVIEW::AST::HtmlDiff.new(html1, html2)
    assert_true(diff.same_hash?)
  end
end
