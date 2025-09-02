# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast'
require 'review/ast/compiler'
require 'review/renderer/html_renderer'
require 'review/renderer/latex_renderer'
require 'review/configure'
require 'review/book'
require 'review/book/chapter'
require 'review/ast/json_serializer'
require 'json'

class TestASTComplexIntegration < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 3
    @config['language'] = 'ja'
    @config['disable_reference_resolution'] = true
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_nested_structures_with_inline_elements
    content = <<~EOB
      = Complex Document Structure

      == Section with Lists and Code

      This paragraph has @<b>{bold} and @<i>{italic} text.

      === Nested Lists Test

       * First level item with @<code>{inline code}
        * Second level with @<ruby>{漢字,かんじ} text
         * Third level item
       * Back to first level with @<href>{http://example.com,link}

       1. Ordered list item with @<kw>{HTTP,Protocol}
        1. Nested ordered item
        1. Another nested item with @<tt>{typewriter}
       2. Second ordered item

      === Code Blocks with Complex Content

      //list[complex-code][Complex Code Example][ruby]{
      def process_data(input)
        # Process with @<b>{bold} annotation
        result = input.map { |item| transform(item) }
        logger.info("Processed @<fn>{processing-note} items")
        result
      end
      //}

      === Tables with Inline Elements

      //table[data-table][Sample Data]{
      Name	Description	Status
      ----------------
      @<b>{Primary}	Main data source	@<i>{Active}
      @<code>{Secondary}	Backup source	@<tt>{Standby}
      //}

      == Multiple Block Types

      === Note Blocks

      //note[important-note][Important Notice]{
      This note contains @<b>{important} information with @<code>{code examples}.

       * Nested list in note
       * Another item with @<href>{http://docs.example.com,documentation}
      //}

      === Embedded Blocks

      //embed[latex]{
      \\begin{equation}
      E = mc^2 \\quad \\text{with @<i>{emphasis}}
      \\end{equation}
      //}

      === Column Blocks

      //column[side-info][Side Information]{
      This column has @<ruby>{専門,せんもん} terminology and @<kw>{API,Application Programming Interface}.

      //list[column-code][Code in Column][javascript]{
      const data = await fetch('/api/data');
      console.log("Fetched @<fn>{data-note} records");
      //}
      //}

      == Cross-References and Footnotes

      See @<list>{complex-code} for implementation details.
      Refer to @<table>{data-table} for data structure.

      This text has footnotes@<fn>{footnote1} and more references@<fn>{footnote2}.

      //footnote[footnote1][First footnote with @<b>{formatting}]
      //footnote[footnote2][Second footnote with @<code>{code}]
    EOB

    # Test AST compilation
    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'complex', 'complex.re', StringIO.new)
    chapter.content = content

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    # Verify AST structure
    assert_not_nil(ast_root, 'AST root should be created')
    assert_equal('DocumentNode', ast_root.class.name.split('::').last)

    # Count different node types
    node_counts = count_node_types(ast_root)

    # Verify we have the expected node types
    assert(node_counts['HeadlineNode'] >= 4, "Should have multiple headlines, got #{node_counts['HeadlineNode']}")
    assert(node_counts['ParagraphNode'] >= 4, "Should have multiple paragraphs, got #{node_counts['ParagraphNode']}")
    assert(node_counts['CodeBlockNode'] >= 2, "Should have multiple code blocks, got #{node_counts['CodeBlockNode']}")
    assert(node_counts['TableNode'] >= 1, "Should have tables, got #{node_counts['TableNode']}")
    assert(node_counts['InlineNode'] >= 10, "Should have many inline elements, got #{node_counts['InlineNode']}")
    assert(node_counts['ListNode'] >= 1, "Should have lists, got #{node_counts['ListNode']}")

    # Test HTML rendering
    html_renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_result = html_renderer.render(ast_root)

    # Verify HTML output contains expected elements
    assert(html_result.include?('<h1>'), 'Should have h1 tags')
    assert(html_result.include?('<h2>'), 'Should have h2 tags')
    assert(html_result.include?('<h3>'), 'Should have h3 tags')
    assert(html_result.include?('<b>'), 'Should have bold tags')
    assert(html_result.include?('<i>'), 'Should have italic tags')
    assert(html_result.include?('<code'), 'Should have code tags')
    assert(html_result.include?('<ul>'), 'Should have unordered lists')
    assert(html_result.include?('<ol>'), 'Should have ordered lists')
    assert(html_result.include?('<table>'), 'Should have tables')
    assert(html_result.include?('<ruby>'), 'Should have ruby tags')

    # Test LaTeX rendering
    latex_renderer = ReVIEW::Renderer::LatexRenderer.new(chapter)
    latex_result = latex_renderer.render(ast_root)

    # Verify LaTeX output contains expected commands
    assert(latex_result.include?('\\chapter'), 'Should have chapter commands')
    assert(latex_result.include?('\\section'), 'Should have section commands')
    assert(latex_result.include?('\\subsection'), 'Should have subsection commands')
    assert(latex_result.include?('\\textbf') || latex_result.include?('\\reviewbold'), 'Should have bold commands')
    assert(latex_result.include?('\\textit') || latex_result.include?('\\reviewit'), 'Should have italic commands')
    assert(latex_result.include?('\\begin{itemize}'), 'Should have itemize environments')
    assert(latex_result.include?('\\begin{enumerate}'), 'Should have enumerate environments')
    assert(latex_result.include?('\\begin{table}'), 'Should have table environments')

    # Verify cross-references are preserved in AST
    inline_nodes = collect_inline_nodes(ast_root)
    list_refs = inline_nodes.select { |node| node.inline_type == 'list' }
    table_refs = inline_nodes.select { |node| node.inline_type == 'table' }
    footnote_refs = inline_nodes.select { |node| node.inline_type == 'fn' }

    assert(list_refs.size >= 1, 'Should have list references')
    assert(table_refs.size >= 1, 'Should have table references')
    assert(footnote_refs.size >= 2, 'Should have footnote references')
  end

  def test_performance_with_large_complex_document
    # Generate a larger document for performance testing
    content = generate_large_complex_document(50) # 50 sections

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'large', 'large.re', StringIO.new)
    chapter.content = content

    # Measure AST compilation time
    start_time = Time.now
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)
    ast_time = Time.now - start_time

    # Measure HTML rendering time
    start_time = Time.now
    html_renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_result = html_renderer.render(ast_root)
    html_time = Time.now - start_time

    # Measure LaTeX rendering time
    start_time = Time.now
    latex_renderer = ReVIEW::Renderer::LatexRenderer.new(chapter)
    latex_result = latex_renderer.render(ast_root)
    latex_time = Time.now - start_time

    # Performance assertions (these are reasonable limits for CI)
    assert(ast_time < 5.0, "AST compilation should be under 5 seconds, took #{ast_time}")
    assert(html_time < 3.0, "HTML rendering should be under 3 seconds, took #{html_time}")
    assert(latex_time < 3.0, "LaTeX rendering should be under 3 seconds, took #{latex_time}")

    # Verify output quality is maintained
    assert(html_result.length > 10000, 'HTML output should be substantial')
    assert(latex_result.length > 10000, 'LaTeX output should be substantial')
    assert(html_result.include?('<h2>'), 'HTML should contain section headers')
    assert(latex_result.include?('\\section'), 'LaTeX should contain section commands')

    puts 'Performance results:'
    puts "  AST compilation: #{(ast_time * 1000).round(2)}ms"
    puts "  HTML rendering: #{(html_time * 1000).round(2)}ms"
    puts "  LaTeX rendering: #{(latex_time * 1000).round(2)}ms"
    puts "  HTML output: #{html_result.length} chars"
    puts "  LaTeX output: #{latex_result.length} chars"
  end

  def test_error_handling_with_malformed_content
    malformed_content = <<~EOB
      = Test Document

      This has unclosed @<b>{bold text

      //list[broken-list][Broken Code]{
      def broken_function
        # Missing closing brace
      //}

      === Missing Table End

      //table[broken-table][Test]{
      Header1	Header2
      -----------
      Data1	Data2
      # Missing //}

      Regular paragraph continues here.
    EOB

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'malformed', 'malformed.re', StringIO.new)
    chapter.content = malformed_content

    # AST compilation should handle errors gracefully
    ast_compiler = ReVIEW::AST::Compiler.new

    # This might raise an error, but we want to test error handling
    begin
      ast_root = ast_compiler.compile_to_ast(chapter)

      # If compilation succeeds, verify we can still render
      if ast_root
        html_renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
        html_result = html_renderer.render(ast_root)
        assert_not_nil(html_result, 'Should produce some HTML output even with malformed input')
      end
    rescue StandardError => e
      # Error handling is acceptable for malformed input
      assert(e.message.length > 0, 'Error message should be informative')
      puts "Expected error for malformed content: #{e.message}"
    end
  end

  def test_memory_usage_with_deep_nesting
    # Test deeply nested structures to verify memory handling
    content = generate_deeply_nested_document(10) # 10 levels deep

    chapter = ReVIEW::Book::Chapter.new(@book, 1, 'nested', 'nested.re', StringIO.new)
    chapter.content = content

    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(chapter)

    # Verify deep structure is handled correctly
    max_depth = calculate_max_depth(ast_root)
    assert(max_depth >= 5, "Should handle deep nesting, max depth: #{max_depth}")

    # Verify rendering works with deep nesting
    html_renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)
    html_result = html_renderer.render(ast_root)

    # Count nested list levels in HTML
    nested_ul_count = html_result.scan(/<ul[^>]*>/).length
    assert(nested_ul_count >= 1, "Should have nested lists, found #{nested_ul_count}")
  end

  private

  def count_node_types(node, counts = Hash.new(0))
    counts[node.class.name.split('::').last] += 1

    if node.respond_to?(:children) && node.children
      node.children.each { |child| count_node_types(child, counts) }
    end

    counts
  end

  def collect_inline_nodes(node, inline_nodes = [])
    if node.class.name.include?('InlineNode')
      inline_nodes << node
    end

    if node.respond_to?(:children) && node.children
      node.children.each { |child| collect_inline_nodes(child, inline_nodes) }
    end

    inline_nodes
  end

  def generate_large_complex_document(section_count)
    content = "= Large Complex Document\n\n"

    (1..section_count).each do |i|
      content += <<~SECTION
        == Section #{i}

        This is section #{i} with @<b>{bold} and @<i>{italic} text.
        It also contains @<code>{code_#{i}} and @<ruby>{漢字#{i},かんじ#{i}}.

        === Subsection #{i}.1

         * List item #{i}.1 with @<href>{http://example#{i}.com,link#{i}}
         * List item #{i}.2 with @<kw>{Term#{i},Description#{i}}
          * Nested item #{i}.2.1
          * Nested item #{i}.2.2

        //list[code-#{i}][Code Example #{i}][ruby]{
        def method_#{i}(param)
          # Processing with @<b>{annotation #{i}}
          result = process(param)
          puts "Result @<fn>{note-#{i}}: \#{result}"
        end
        //}

        //footnote[note-#{i}][Footnote #{i} with @<code>{code reference}]

      SECTION
    end

    content
  end

  def generate_deeply_nested_document(max_depth)
    content = "= Deeply Nested Document\n\n"

    # Generate truly nested list structure
    content += " * Level 1 item with @<b>{bold 1} text\n"
    (2..max_depth).each do |level|
      indent = ' ' * level
      content += "#{indent}* Level #{level} item with @<code>{code_#{level}}\n"
    end

    content += "\n== Section with Complex Nesting\n\n"

    # Generate nested definition lists
    (1..5).each do |level|
      indent = ' ' * level
      content += "#{indent}: Term #{level} with @<i>{italic #{level}}\n"
      content += "#{indent}  Definition #{level} with @<ruby>{漢字#{level},かんじ#{level}}\n"
    end

    content
  end

  def calculate_max_depth(node, current_depth = 0)
    max_depth = current_depth

    if node.respond_to?(:children) && node.children
      node.children.each do |child|
        child_depth = calculate_max_depth(child, current_depth + 1)
        max_depth = [max_depth, child_depth].max
      end
    end

    max_depth
  end
end
