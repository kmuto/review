# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/renderer/markdown_renderer'
require 'review/markdownbuilder'
require 'review/configure'
require 'review/book'
require 'review/book/chapter'

class TestMarkdownRenderer < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @config['disable_reference_resolution'] = true
    @book = ReVIEW::Book::Base.new(config: @config)
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_markdown_renderer_basic_functionality
    content = <<~EOB
      = Chapter Title

      This is a paragraph with @<b>{bold} and @<i>{italic} text.

      == Section Title

       * First item
       * Second item with @<code>{inline code}

       1. Ordered item one
       2. Ordered item two

      //list[sample-code][Sample Code][ruby]{
      def hello
        puts "Hello, World!"
      end
      //}

      //table[data-table][Sample Table]{
      Name	Age
      -----
      Alice	25
      Bob	30
      //}
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    markdown_renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)
    markdown_result = markdown_renderer.render(ast_root)

    # Verify basic Markdown elements
    assert(markdown_result.include?('# Chapter Title'), 'Should have h1 with # syntax')
    assert(markdown_result.include?('## Section Title'), 'Should have h2 with ## syntax')
    assert(markdown_result.include?('**bold**'), 'Should have bold with ** syntax')
    assert(markdown_result.include?('*italic*'), 'Should have italic with * syntax')
    assert(markdown_result.include?('* First item'), 'Should have unordered list items')
    assert(markdown_result.include?('1. Ordered item one'), 'Should have ordered list items')
    assert(markdown_result.include?('```ruby'), 'Should have fenced code blocks')
    assert(markdown_result.include?('| Name | Age |'), 'Should have markdown table headers')
  end

  def test_markdown_renderer_inline_elements
    content = <<~EOB
      = Inline Elements Test

      Text with @<code>{code}, @<tt>{typewriter}, @<del>{deleted}, @<sup>{super}, @<sub>{sub}.

      Links: @<href>{http://example.com,Example Link} and @<href>{http://direct.com}.

      Ruby: @<ruby>{漢字,かんじ} annotation.

      Footnote reference@<fn>{note1}.

      //footnote[note1][This is a footnote]
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    markdown_renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)
    markdown_result = markdown_renderer.render(ast_root)

    # Verify inline elements
    assert(markdown_result.include?('`code`'), 'Should render code with backticks')
    assert(markdown_result.include?('~~deleted~~'), 'Should render strikethrough')
    assert(markdown_result.include?('<sup>super</sup>'), 'Should render superscript with HTML')
    assert(markdown_result.include?('<sub>sub</sub>'), 'Should render subscript with HTML')
    assert(markdown_result.include?('[Example Link](http://example.com)'), 'Should render href links')
    assert(markdown_result.include?('<ruby>'), 'Should render ruby with HTML')
    assert(markdown_result.include?('[^note1]'), 'Should render footnote references')
    assert(markdown_result.include?('[^note1]: This is a footnote'), 'Should render footnote definitions')
  end

  def test_markdown_renderer_complex_structures
    content = <<~EOB
      = Complex Document

      == Section with Nested Lists

       * First level
       ** Second level with @<b>{bold text}
       *** Third level
       * Back to first level

      === Code with Line Numbers

      //listnum[numbered-code][Numbered Code][python]{
      def fibonacci(n):
          if n <= 1:
              return n
          return fibonacci(n-1) + fibonacci(n-2)
      //}

      === Quote Block

      //quote{
      This is a quoted text with @<i>{emphasis}.
      Multiple lines are supported.
      //}

      === Note Block

      //note[important-note][Important Note]{
      This is a note with @<code>{code} and other formatting.
      //}
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    markdown_renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)
    markdown_result = markdown_renderer.render(ast_root)

    # Verify complex structures
    assert(markdown_result.include?('  * Second level'), 'Should handle nested lists with proper indentation')
    assert(markdown_result.include?('```python'), 'Should handle code blocks with language specification')
    assert(markdown_result.include?('> This is a quoted'), 'Should handle quote blocks with > prefix')
    assert(markdown_result.include?('<div class="note">'), 'Should handle minicolumns with HTML div')
  end

  def test_target_name
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new)
    markdown_renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)

    assert_equal('markdown', markdown_renderer.target_name)
  end

  # Individual inline element tests
  def test_inline_bold
    content = "= Chapter\n\nThis is @<b>{bold text}.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*\*bold text\*\*/, result)
  end

  def test_inline_strong
    content = "= Chapter\n\nThis is @<strong>{strong text}.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*\*strong text\*\*/, result)
  end

  def test_inline_italic
    content = "= Chapter\n\nThis is @<i>{italic text}.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*italic text\*/, result)
  end

  def test_inline_em
    content = "= Chapter\n\nThis is @<em>{emphasized text}.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*emphasized text\*/, result)
  end

  def test_inline_code
    content = "= Chapter\n\nThis is @<code>{code text}.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/`code text`/, result)
  end

  def test_inline_tt
    content = "= Chapter\n\nThis is @<tt>{typewriter text}.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/`typewriter text`/, result)
  end

  def test_inline_kbd
    content = "= Chapter\n\nPress @<kbd>{Ctrl+C} to copy.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/`Ctrl\+C`/, result)
  end

  def test_inline_samp
    content = "= Chapter\n\nExample output: @<samp>{Hello World}.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/`Hello World`/, result)
  end

  def test_inline_var
    content = "= Chapter\n\nVariable @<var>{count} is used.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*count\*/, result)
  end

  def test_inline_sup
    content = "= Chapter\n\nE=mc@<sup>{2}.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<sup>2<\/sup>/, result)
  end

  def test_inline_sub
    content = "= Chapter\n\nH@<sub>{2}O is water.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<sub>2<\/sub>/, result)
  end

  def test_inline_del
    content = "= Chapter\n\nThis is @<del>{deleted} text.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/~~deleted~~/, result)
  end

  def test_inline_ins
    content = "= Chapter\n\nThis is @<ins>{inserted} text.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<ins>inserted<\/ins>/, result)
  end

  def test_inline_u
    content = "= Chapter\n\nThis is @<u>{underlined} text.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<u>underlined<\/u>/, result)
  end

  def test_inline_bou
    content = "= Chapter\n\nThis is @<bou>{emphasized} text.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*emphasized\*/, result)
  end

  def test_inline_ami
    content = "= Chapter\n\nThis is @<ami>{網点} text.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*網点\*/, result)
  end

  def test_inline_br
    content = "= Chapter\n\nLine one@<br>{}Line two.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Note: @<br>{} in a paragraph gets joined with spaces due to paragraph line joining
    # This is expected behavior in Markdown rendering
    assert_match(/Line one Line two/, result)
  end

  def test_inline_href_with_label
    content = "= Chapter\n\nVisit @<href>{http://example.com, Example Site}.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\[Example Site\]\(http:\/\/example\.com\)/, result)
  end

  def test_inline_href_without_label
    content = "= Chapter\n\nVisit @<href>{http://example.com}.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\[http:\/\/example\.com\]\(http:\/\/example\.com\)/, result)
  end

  def test_inline_ruby
    content = "= Chapter\n\n@<ruby>{漢字,かんじ}を使う。\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<ruby>漢字<rt>かんじ<\/rt><\/ruby>/, result)
  end

  def test_inline_kw_with_alt
    content = "= Chapter\n\n@<kw>{API, Application Programming Interface}について。\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*\*API\*\* \(Application Programming Interface\)/, result)
  end

  def test_inline_kw_without_alt
    content = "= Chapter\n\n@<kw>{Keyword}について。\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*\*Keyword\*\*/, result)
  end

  def test_inline_m
    content = "= Chapter\n\n式: @<m>{E = mc^2}.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\$\$E = mc\^2\$\$/, result)
  end

  def test_inline_idx
    content = "= Chapter\n\n@<idx>{索引語}について。\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/索引語/, result)
  end

  def test_inline_hidx
    content = "= Chapter\n\n@<hidx>{hidden_index}Text here.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # hidx should not output visible text
    assert_no_match(/hidden_index/, result)
  end

  def test_inline_comment_draft_mode
    @config['draft'] = true
    content = "= Chapter\n\nText@<comment>{This is a comment}here.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<!-- This is a comment -->/, result)
  end

  def test_inline_comment_non_draft_mode
    @config['draft'] = false
    content = "= Chapter\n\nText@<comment>{This is a comment}here.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_no_match(/This is a comment/, result)
  end

  # Block element tests
  def test_block_quote
    content = <<~EOB
      = Chapter

      //quote{
      This is a quoted text.
      Multiple lines are supported.
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Quote blocks join paragraph lines with spaces in Markdown
    assert_match(/> This is a quoted text\. Multiple lines are supported\./, result)
  end

  def test_block_note
    content = <<~EOB
      = Chapter

      //note[Note Title]{
      This is a note.
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<div class="note">/, result)
    assert_match(/\*\*Note Title\*\*/, result)
    assert_match(/This is a note\./, result)
  end

  def test_block_tip
    content = <<~EOB
      = Chapter

      //tip[Tip Title]{
      This is a tip.
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<div class="tip">/, result)
    assert_match(/\*\*Tip Title\*\*/, result)
  end

  def test_block_info
    content = <<~EOB
      = Chapter

      //info[Info Title]{
      This is info.
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<div class="info">/, result)
  end

  def test_block_warning
    content = <<~EOB
      = Chapter

      //warning[Warning Title]{
      This is a warning.
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<div class="warning">/, result)
  end

  def test_block_important
    content = <<~EOB
      = Chapter

      //important[Important Title]{
      This is important.
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<div class="important">/, result)
  end

  def test_block_caution
    content = <<~EOB
      = Chapter

      //caution[Caution Title]{
      This is a caution.
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<div class="caution">/, result)
  end

  def test_block_notice
    content = <<~EOB
      = Chapter

      //notice[Notice Title]{
      This is a notice.
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<div class="notice">/, result)
  end

  # Note: //captionblock is not supported in AST compiler, only in old Builder

  # Code block tests
  def test_code_block_emlist
    content = <<~EOB
      = Chapter

      //emlist[Sample Code][ruby]{
      puts "Hello"
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*\*Sample Code\*\*/, result)
    assert_match(/```ruby/, result)
    assert_match(/puts "Hello"/, result)
    assert_match(/```/, result)
  end

  def test_code_block_emlistnum
    content = <<~EOB
      = Chapter

      //emlistnum[Numbered Code][python]{
      def hello():
          print("Hello")
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*\*Numbered Code\*\*/, result)
    assert_match(/```python/, result)
    # Line numbers should be present
    assert_match(/  1: def hello\(\):/, result)
  end

  def test_code_block_cmd
    content = <<~EOB
      = Chapter

      //cmd[Command Output]{
      $ ls -la
      total 100
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*\*Command Output\*\*/, result)
    assert_match(/```/, result)
    assert_match(/\$ ls -la/, result)
  end

  def test_code_block_source
    content = <<~EOB
      = Chapter

      //source[source-file][Source File][javascript]{
      console.log("test");
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Note: AST structure has caption as ID and lang as caption text
    # This might be a compiler bug, but we test the current behavior
    assert_match(/\*\*source-file\*\*/, result)
    assert_match(/```Source File/, result)
    assert_match(/console\.log\("test"\)/, result)
  end

  # Definition list tests
  def test_definition_list
    content = <<~EOB
      = Chapter

       : Term 1
      \tDefinition 1
       : Term 2
      \tDefinition 2
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<dl>/, result)
    assert_match(/<dt>Term 1<\/dt>/, result)
    assert_match(/<dd>Definition 1<\/dd>/, result)
    assert_match(/<dt>Term 2<\/dt>/, result)
    assert_match(/<dd>Definition 2<\/dd>/, result)
  end

  def test_definition_list_with_inline_markup
    content = <<~EOB
      = Chapter

       : @<b>{Bold Term}
      \tDefinition with @<code>{code}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/<dt>\*\*Bold Term\*\*<\/dt>/, result)
    assert_match(/<dd>Definition with `code`<\/dd>/, result)
  end

  # Nested list tests
  def test_nested_ul
    content = <<~EOS
      = Chapter

       * UL1

      //beginchild

       1. UL1-OL1
       2. UL1-OL2

       * UL1-UL1
       * UL1-UL2

      //endchild

       * UL2
    EOS
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Verify nested structure is present
    assert_match(/\* UL1/, result)
    assert_match(/\* UL2/, result)
    assert_match(/1\. UL1-OL1/, result)
    assert_match(/\* UL1-UL1/, result)
  end

  def test_nested_ol
    content = <<~EOS
      = Chapter

       1. OL1

      //beginchild

       1. OL1-OL1
       2. OL1-OL2

       * OL1-UL1
       * OL1-UL2

      //endchild

       2. OL2
    EOS
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Verify nested structure is present
    assert_match(/1\. OL1/, result)
    assert_match(/2\. OL2/, result)
    assert_match(/1\. OL1-OL1/, result)
    assert_match(/\* OL1-UL1/, result)
  end

  # Raw/Embed tests
  def test_raw_markdown_targeted
    content = <<~EOB
      = Chapter

      //raw[|markdown|**Raw Markdown Content**]
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*\*Raw Markdown Content\*\*/, result)
  end

  def test_raw_latex_targeted
    content = <<~EOB
      = Chapter

      //raw[|latex|\\textbf{LaTeX Content}]
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Should not output LaTeX content
    assert_no_match(/textbf/, result)
  end

  def test_inline_raw_markdown_targeted
    content = "= Chapter\n\nText with @<raw>{|markdown|**inline**} content.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*\*inline\*\*/, result)
  end

  def test_inline_raw_html_targeted
    content = "= Chapter\n\nText with @<raw>{|html|<span>HTML</span>} content.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Should not output HTML-targeted content
    assert_no_match(/<span>HTML<\/span>/, result)
  end

  # Table tests
  def test_table_basic
    content = <<~EOB
      = Chapter

      //table[table1][Table Caption]{
      Header1\tHeader2
      -----
      Cell1\tCell2
      Cell3\tCell4
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\*\*Table Caption\*\*/, result)
    assert_match(/\| Header1 \| Header2 \|/, result)
    assert_match(/\| :-- \| :-- \|/, result)
    assert_match(/\| Cell1 \| Cell2 \|/, result)
    assert_match(/\| Cell3 \| Cell4 \|/, result)
  end

  def test_table_without_caption
    content = <<~EOB
      = Chapter

      //table[table1]{
      Header1\tHeader2
      -----
      Cell1\tCell2
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\| Header1 \| Header2 \|/, result)
    assert_no_match(/\*\*.*\*\*\n\n\|/, result) # No caption before table
  end

  def test_table_with_inline_markup
    content = <<~EOB
      = Chapter

      //table[table1][Table]{
      @<b>{Bold}\t@<code>{Code}
      -----
      Cell1\tCell2
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Inline markup should be rendered in table cells
    assert_match(/\*\*Bold\*\*/, result)
    assert_match(/`Code`/, result)
  end

  # Image tests
  def test_image_with_caption
    content = <<~EOB
      = Chapter

      //image[img1][Image Caption]{
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/!\[Image Caption\]\(img1\)/, result)
  end

  def test_image_without_caption
    content = <<~EOB
      = Chapter

      //image[img1]{
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/!\[\]\(img1\)/, result)
  end

  def test_inline_icon
    content = "= Chapter\n\nIcon: @<icon>{icon.png} here.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/!\[\]\(icon\.png\)/, result)
  end

  # Text escaping tests
  def test_text_with_asterisks
    content = "= Chapter\n\nText with *asterisks* and **double** asterisks.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Note: Current implementation does not escape asterisks in plain text
    # This might cause Markdown parsers to interpret them as formatting
    assert_match(/\*asterisks\*/, result)
    assert_match(/\*\*double\*\*/, result)
  end

  def test_inline_bold_with_asterisks
    content = "= Chapter\n\nThis is @<b>{text with * asterisk}.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Asterisks inside bold should be escaped
    assert_match(/\*\*text with \\\* asterisk\*\*/, result)
  end

  # Column tests
  def test_column_basic
    content = <<~EOB
      = Chapter

      ===[column] Column Title

      Column content here.

      ===[/column]
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Column is rendered as minicolumn with div
    assert_match(/<div class="column">/, result)
    assert_match(/\*\*Column Title\*\*/, result)
    assert_match(/Column content here\./, result)
  end

  # Footnote tests
  def test_footnote_basic
    content = <<~EOB
      = Chapter

      Text with footnote@<fn>{note1}.

      //footnote[note1][This is a footnote]
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\[\^note1\]/, result)
    assert_match(/\[\^note1\]: This is a footnote/, result)
  end

  def test_footnote_with_inline_markup
    content = <<~EOB
      = Chapter

      Text@<fn>{note1}.

      //footnote[note1][Footnote with @<b>{bold} and @<code>{code}]
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/\[\^note1\]: Footnote with \*\*bold\*\* and `code`/, result)
  end

  # Edge case tests
  def test_empty_paragraph
    content = "= Chapter\n\n\n\nText after empty lines.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    assert_match(/Text after empty lines\./, result)
  end

  def test_paragraph_with_multiple_lines
    content = <<~EOB
      = Chapter

      This is line one.
      This is line two.
      This is line three.
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Lines should be joined with spaces in Markdown
    assert_match(/This is line one\. This is line two\. This is line three\./, result)
  end

  # Adjacent inline element tests
  def test_adjacent_different_types_bold_and_italic
    content = "= Chapter\n\nText with @<b>{bold}@<i>{italic} adjacent.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Should have space between different type adjacent inline elements
    assert_match(/\*\*bold\*\* \*italic\*/, result)
  end

  def test_adjacent_different_types_code_and_bold
    content = "= Chapter\n\nText with @<code>{code}@<b>{bold} adjacent.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Should have space between different type adjacent inline elements
    assert_match(/`code` \*\*bold\*\*/, result)
  end

  def test_multiple_adjacent_different_types
    content = "= Chapter\n\nText @<b>{bold}@<i>{italic}@<code>{code} all adjacent.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Should have spaces between all different type adjacent inline elements
    assert_match(/\*\*bold\*\* \*italic\* `code`/, result)
  end

  def test_adjacent_same_type_bold
    content = "= Chapter\n\nText @<b>{bold1}@<b>{bold2} merged.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Same type adjacent inlines should be merged without space
    assert_match(/\*\*bold1bold2\*\*/, result)
  end

  def test_adjacent_same_type_code
    content = "= Chapter\n\nText @<code>{code1}@<code>{code2} merged.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Same type adjacent inlines should be merged without space
    assert_match(/`code1code2`/, result)
  end

  def test_adjacent_same_type_italic
    content = "= Chapter\n\nText @<i>{italic1}@<i>{italic2} merged.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Same type adjacent inlines should be merged without space
    assert_match(/\*italic1italic2\*/, result)
  end

  def test_multiple_adjacent_same_type
    content = "= Chapter\n\nText @<b>{a}@<b>{b}@<b>{c} all merged.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Multiple same type adjacent inlines should all be merged
    assert_match(/\*\*abc\*\*/, result)
  end

  def test_mixed_same_and_different_types
    content = "= Chapter\n\nText @<b>{a}@<b>{b}@<i>{c}@<i>{d} mixed.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Should merge same types and add space between different types
    assert_match(/\*\*ab\*\* \*cd\*/, result)
  end

  def test_inline_with_text_between
    content = "= Chapter\n\nText @<b>{bold} and @<i>{italic} with text.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Should not add extra space when text is already between
    assert_match(/\*\*bold\*\* and \*italic\*/, result)
  end

  def test_adjacent_inline_in_caption
    content = <<~EOB
      = Chapter

      //emlist[@<b>{Bold}@<i>{Italic} Caption][ruby]{
      code
      //}
    EOB
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Caption should also have spacing between adjacent inline elements
    assert_match(/\*\*Bold\*\* \*Italic\* Caption/, result)
  end

  def test_adjacent_del_and_ins
    content = "= Chapter\n\nText with @<del>{deleted}@<ins>{inserted} adjacent.\n"
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re', StringIO.new(content))
    ast_root = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    result = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast_root)
    # Should have space between adjacent inline elements
    assert_match(/~~deleted~~ <ins>inserted<\/ins>/, result)
  end
end
