# frozen_string_literal: true

require_relative 'test_helper'
require 'review'
require 'json'

class JSONBuilderTest < Test::Unit::TestCase
  include ReVIEW

  def setup
    ReVIEW::I18n.setup
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book = Book::Base.new('.')
    @book.config = @config
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    @builder = JSONBuilder.new
    @compiler = ReVIEW::Compiler.new(@builder)
    @chapter = Book::Chapter.new(@book, 1, '-', nil, StringIO.new)
    location = Location.new(nil, nil)
    @builder.bind(@compiler, @chapter, location)
    I18n.setup('ja')
  end

  def test_result_returns_valid_json
    @chapter.content = "= Test\n\nThis is a test.\n"
    result = @compiler.compile(@chapter)
    assert_nothing_raised { JSON.parse(result) }
  end

  def test_simple_document_structure
    actual = compile_block("= Test Chapter\n")
    expected = <<~JSON.chomp
      {
        "type": "DocumentNode",
        "location": {
          "filename": null,
          "lineno": 2
        },
        "children": [
          {
            "type": "HeadlineNode",
            "location": {
              "filename": null,
              "lineno": 2
            },
            "children": [],
            "level": 1,
            "label": null,
            "caption": "Test Chapter"
          }
        ],
        "title": "",
        "chapters": []
      }
    JSON
    assert_equal expected, actual
  end

  def test_headline_level1
    actual = compile_block("={test} this is test.\n")
    expected = <<~JSON.chomp
      {
        "type": "DocumentNode",
        "location": {
          "filename": null,
          "lineno": 2
        },
        "children": [
          {
            "type": "HeadlineNode",
            "location": {
              "filename": null,
              "lineno": 2
            },
            "children": [],
            "level": 1,
            "label": "test",
            "caption": "this is test."
          }
        ],
        "title": "",
        "chapters": []
      }
    JSON
    assert_equal expected, actual
  end

  def test_headline_level2
    actual = compile_block("=={test} this is test.\n")
    expected = <<~JSON.chomp
      {
        "type": "DocumentNode",
        "location": {
          "filename": null,
          "lineno": 2
        },
        "children": [
          {
            "type": "HeadlineNode",
            "location": {
              "filename": null,
              "lineno": 2
            },
            "children": [],
            "level": 2,
            "label": "test",
            "caption": "this is test."
          }
        ],
        "title": "",
        "chapters": []
      }
    JSON
    assert_equal expected, actual
  end

  def test_paragraph
    actual = compile_block("This is a simple paragraph.\n")
    expected = <<~JSON.chomp
      {
        "type": "DocumentNode",
        "location": {
          "filename": null,
          "lineno": 2
        },
        "children": [
          {
            "type": "ParagraphNode",
            "location": {
              "filename": null,
              "lineno": 2
            },
            "children": [
              {
                "type": "TextNode",
                "location": {
                  "filename": null,
                  "lineno": 2
                },
                "children": [],
                "content": "This is a simple paragraph."
              }
            ]
          }
        ],
        "title": "",
        "chapters": []
      }
    JSON
    assert_equal expected, actual
  end

  def test_ast_mode_paragraph_with_inline_elements
    @compiler = ReVIEW::Compiler.new(@builder, ast_mode: true, ast_elements: %i[paragraph])
    @builder.bind(@compiler, @chapter, @builder.instance_variable_get(:@location))

    actual = compile_block("This has @<b>{bold} and @<i>{italic} text.\n")
    expected = <<~JSON.chomp
      {
        "type": "DocumentNode",
        "location": {
          "filename": null,
          "lineno": 2
        },
        "children": [
          {
            "type": "ParagraphNode",
            "location": {
              "filename": null,
              "lineno": 2
            },
            "children": [
              {
                "type": "TextNode",
                "location": {
                  "filename": null,
                  "lineno": 2
                },
                "children": [],
                "content": "This has "
              },
              {
                "type": "InlineNode",
                "location": {
                  "filename": null,
                  "lineno": 2
                },
                "children": [
                  {
                    "type": "TextNode",
                    "location": {
                      "filename": null,
                      "lineno": 2
                    },
                    "children": [],
                    "content": "bold"
                  }
                ],
                "inline_type": "b",
                "args": [
                  "bold"
                ]
              },
              {
                "type": "TextNode",
                "location": {
                  "filename": null,
                  "lineno": 2
                },
                "children": [],
                "content": " and "
              },
              {
                "type": "InlineNode",
                "location": {
                  "filename": null,
                  "lineno": 2
                },
                "children": [
                  {
                    "type": "TextNode",
                    "location": {
                      "filename": null,
                      "lineno": 2
                    },
                    "children": [],
                    "content": "italic"
                  }
                ],
                "inline_type": "i",
                "args": [
                  "italic"
                ]
              },
              {
                "type": "TextNode",
                "location": {
                  "filename": null,
                  "lineno": 2
                },
                "children": [],
                "content": " text."
              }
            ]
          }
        ],
        "title": "",
        "chapters": []
      }
    JSON
    assert_json_equal(expected, actual)
  end

  def test_ast_mode_headline_and_paragraph
    @compiler = ReVIEW::Compiler.new(@builder, ast_mode: true, ast_elements: %i[headline paragraph])
    @builder.bind(@compiler, @chapter, @builder.instance_variable_get(:@location))

    content = <<~EOB
      = Test Headline
      
      This paragraph has @<code>{inline code} elements.
    EOB

    actual = compile_block(content)
    json = JSON.parse(actual)

    # Check headline
    headline = json['children'].find { |child| child['type'] == 'HeadlineNode' }
    assert_not_nil(headline)
    assert_equal 'Test Headline', headline['caption']

    # Check paragraph with inline elements
    paragraph = json['children'].find { |child| child['type'] == 'ParagraphNode' }
    assert_not_nil(paragraph)
    inline_code = paragraph['children'].find { |child| child['type'] == 'InlineNode' && child['inline_type'] == 'code' }
    assert_not_nil(inline_code)
    assert_equal ['inline code'], inline_code['args']
  end

  def test_list_block
    actual = compile_block("//list[sample][Sample List]{\nline 1\nline 2\n//}\n")
    expected = <<~JSON.chomp
      {
        "type": "DocumentNode",
        "location": {
          "filename": null,
          "lineno": 5
        },
        "children": [
          {
            "type": "CodeBlockNode",
            "location": {
              "filename": null,
              "lineno": 5
            },
            "children": [],
            "lang": null,
            "id": "sample",
            "caption": "Sample List",
            "lines": [
              "line 1",
              "line 2"
            ],
            "line_numbers": false
          }
        ],
        "title": "",
        "chapters": []
      }
    JSON
    assert_json_equal(expected, actual)
  end

  def test_listnum_block
    actual = compile_block("//listnum[sample][Sample List]{\nline 1\nline 2\n//}\n")
    json = JSON.parse(actual)

    list_block = json['children'].find { |child| child['type'] == 'CodeBlockNode' }
    assert_not_nil(list_block)
    assert_equal 'sample', list_block['id']
    assert_equal 'Sample List', list_block['caption']
    assert_equal ['line 1', 'line 2'], list_block['lines']
    assert_equal true, list_block['line_numbers']
  end

  def test_emlist_block
    actual = compile_block("//emlist[Sample Code]{\ncode line 1\ncode line 2\n//}\n")
    json = JSON.parse(actual)

    code_block = json['children'].find { |child| child['type'] == 'CodeBlockNode' }
    assert_not_nil(code_block)
    assert_equal 'Sample Code', code_block['caption']
    assert_equal ['code line 1', 'code line 2'], code_block['lines']
    assert_equal false, code_block['line_numbers']
  end

  def test_emlistnum_block
    actual = compile_block("//emlistnum[Sample Code]{\ncode line 1\ncode line 2\n//}\n")
    json = JSON.parse(actual)

    code_block = json['children'].find { |child| child['type'] == 'CodeBlockNode' }
    assert_not_nil(code_block)
    assert_equal 'Sample Code', code_block['caption']
    assert_equal ['code line 1', 'code line 2'], code_block['lines']
    assert_equal true, code_block['line_numbers']
  end

  def test_cmd_block
    actual = compile_block("//cmd[Shell Commands]{\nls -la\ngrep pattern file\n//}\n")
    json = JSON.parse(actual)

    cmd_block = json['children'].find { |child| child['type'] == 'CodeBlockNode' }
    assert_not_nil(cmd_block)
    assert_equal 'Shell Commands', cmd_block['caption']
    assert_equal 'shell', cmd_block['lang']
    assert_equal ['ls -la', 'grep pattern file'], cmd_block['lines']
  end

  def test_source_block
    actual = compile_block("//source[ruby][Ruby Code]{\ndef hello\n  puts 'world'\nend\n//}\n")
    json = JSON.parse(actual)

    source_block = json['children'].find { |child| child['type'] == 'CodeBlockNode' }
    assert_not_nil(source_block)
    assert_equal 'ruby', source_block['caption'] # JsonBuilder treats first arg as caption
    assert_equal 'Ruby Code', source_block['lang']
    assert_equal ['def hello', '  puts \'world\'', 'end'], source_block['lines']
  end

  def test_image_block
    actual = compile_block("//image[figure1][Sample Figure]{\n//}\n")
    json = JSON.parse(actual)

    image = json['children'].find { |child| child['type'] == 'ImageNode' }
    assert_not_nil(image)
    assert_equal 'figure1', image['id']
    assert_equal 'Sample Figure', image['caption']
  end

  def test_table_block
    actual = compile_block("//table[sample][Sample Table]{\nHeader1\tHeader2\n------------\nData1\tData2\nData3\tData4\n//}\n")
    json = JSON.parse(actual)

    table = json['children'].find { |child| child['type'] == 'TableNode' }
    assert_not_nil(table)
    assert_equal 'sample', table['id']
    assert_equal 'Sample Table', table['caption']
    assert_equal [['Header1', 'Header2']], table['headers']
    assert_equal [['Data1', 'Data2'], ['Data3', 'Data4']], table['rows']
  end

  def test_embed_block
    @compiler = ReVIEW::Compiler.new(@builder, ast_mode: true, ast_elements: %i[embed])
    @builder.bind(@compiler, @chapter, @builder.instance_variable_get(:@location))

    actual = compile_block("//embed[html]{\n<div>HTML content</div>\n<p>Paragraph</p>\n//}\n")
    json = JSON.parse(actual)

    embed = json['children'].find { |child| child['type'] == 'EmbedNode' }
    assert_not_nil(embed)
    assert_equal 'html', embed['arg']
    assert_equal 'block', embed['embed_type']
    assert_equal ['<div>HTML content</div>', '<p>Paragraph</p>'], embed['lines']
  end

  def test_quote_block
    actual = compile_block("//quote{\nThis is a quotation.\nWith multiple lines.\n//}\n")
    json = JSON.parse(actual)

    # Quote blocks are handled as paragraph nodes in JsonBuilder
    quote = json['children'].find { |child| child['type'] == 'ParagraphNode' }
    assert_not_nil(quote)
  end

  def test_inline_elements_ast_structure
    # Test that compile_inline returns AST structure for inline elements

    # Test @<code>{code snippet}
    result = compile_inline_ast('@<code>{code snippet}')
    json = JSON.parse(result)

    assert_equal 'InlineNode', json['type']
    assert_equal 'code', json['inline_type']
    assert_equal ['code snippet'], json['args']
    assert_equal 1, json['children'].size
    assert_equal 'TextNode', json['children'][0]['type']
    assert_equal 'code snippet', json['children'][0]['content']

    # Test @<b>{bold text}
    result = compile_inline_ast('@<b>{bold text}')
    json = JSON.parse(result)

    assert_equal 'InlineNode', json['type']
    assert_equal 'b', json['inline_type']
    assert_equal ['bold text'], json['args']
    assert_equal 1, json['children'].size
    assert_equal 'TextNode', json['children'][0]['type']
    assert_equal 'bold text', json['children'][0]['content']

    # Test @<i>{italic text}
    result = compile_inline_ast('@<i>{italic text}')
    json = JSON.parse(result)

    assert_equal 'InlineNode', json['type']
    assert_equal 'i', json['inline_type']
    assert_equal ['italic text'], json['args']
  end

  def test_inline_elements_unprocessed
    # JsonBuilder returns unprocessed inline content for traditional mode
    assert_equal '@<b>{bold text}', compile_inline('@<b>{bold text}')
    assert_equal '@<i>{italic text}', compile_inline('@<i>{italic text}')
    assert_equal '@<code>{code snippet}', compile_inline('@<code>{code snippet}')
    assert_equal '@<tt>{typewriter text}', compile_inline('@<tt>{typewriter text}')
    assert_equal '@<ruby>{漢字,かんじ}', compile_inline('@<ruby>{漢字,かんじ}')
    assert_equal '@<href>{http://example.com,Example}', compile_inline('@<href>{http://example.com,Example}')
    assert_equal '@<kw>{keyword,explanation}', compile_inline('@<kw>{keyword,explanation}')
    assert_equal '@<w>{filename}', compile_inline('@<w>{filename}')
    assert_equal '@<wb>{wordfile}', compile_inline('@<wb>{wordfile}')
    assert_equal '@<embed>{custom_content}', compile_inline('@<embed>{custom_content}')
    assert_equal '@<hd>{Introduction}', compile_inline('@<hd>{Introduction}')
    assert_equal '@<img>{figure1}', compile_inline('@<img>{figure1}')
    assert_equal '@<list>{sample1}', compile_inline('@<list>{sample1}')
    assert_equal '@<table>{table1}', compile_inline('@<table>{table1}')
  end

  def test_raw_command
    # Test that raw commands don't cause compilation errors
    actual = compile_block("//raw[|html|<div>Raw HTML</div>]\n")
    json = JSON.parse(actual)

    # Raw commands are processed traditionally and don't appear as AST nodes
    assert json['children'].is_a?(Array)
  end

  def test_complex_document_structure
    content = <<~EOB
      = Chapter Title
      
      This is the introduction paragraph with @<b>{bold} text.
      
      == Section Title
      
      //list[example][Code Example]{
      def example
        puts "Hello World"
      end
      //}
      
      This paragraph references @<list>{example}.
      
      //table[data][Sample Data]{
      Name	Age
      --------
      Alice	25
      Bob	30
      //}
      
      See @<table>{data} for details.
    EOB

    @compiler = ReVIEW::Compiler.new(@builder, ast_mode: true, ast_elements: %i[headline paragraph list table])
    @builder.bind(@compiler, @chapter, @builder.instance_variable_get(:@location))

    actual = compile_block(content)
    json = JSON.parse(actual)

    # Check document structure
    assert_equal 'DocumentNode', json['type']
    assert json['children'].is_a?(Array)

    # Count different types of nodes
    headlines = json['children'].select { |child| child['type'] == 'HeadlineNode' }
    paragraphs = json['children'].select { |child| child['type'] == 'ParagraphNode' }
    code_blocks = json['children'].select { |child| child['type'] == 'CodeBlockNode' }
    tables = json['children'].select { |child| child['type'] == 'TableNode' }

    assert_equal 2, headlines.size
    assert(headlines.any? { |h| h['level'] == 1 && h['caption'] == 'Chapter Title' })
    assert(headlines.any? { |h| h['level'] == 2 && h['caption'] == 'Section Title' })

    assert paragraphs.size >= 3
    assert_equal 1, code_blocks.size
    assert_equal 1, tables.size
  end

  def test_location_information
    actual = compile_block("= Test Headline\n")
    json = JSON.parse(actual)

    headline = json['children'].find { |child| child['type'] == 'HeadlineNode' }
    assert_not_nil(headline)
    assert headline.key?('location')
    assert headline['location'].key?('filename')
  end

  def test_empty_document
    actual = compile_block('')
    expected = <<~JSON.chomp
      {
        "type": "DocumentNode",
        "location": {
          "filename": null,
          "lineno": 1
        },
        "children": [],
        "title": "",
        "chapters": []
      }
    JSON
    assert_equal expected, actual
  end

  def test_add_ast_node_method
    # Test the special add_ast_node method for direct AST handling
    @compiler = ReVIEW::Compiler.new(@builder, ast_mode: true, ast_elements: %i[headline])
    @builder.bind(@compiler, @chapter, @builder.instance_variable_get(:@location))

    actual = compile_block("= Direct AST Test\n")
    json = JSON.parse(actual)

    headline = json['children'].find { |child| child['type'] == 'HeadlineNode' }
    assert_not_nil(headline)
    assert_equal 'Direct AST Test', headline['caption']
  end

  def test_json_output_format
    actual = compile_block("= Test\n\nParagraph with @<b>{bold}.\n")

    # Should be valid JSON
    assert_nothing_raised { JSON.parse(actual) }

    # Should be pretty printed (contains newlines and indentation)
    assert actual.include?("\n")
    assert actual.include?('  ')
  end

  private

  def compile_block_json(text)
    @chapter.content = text
    @chapter.execute_indexer(force: true)
    @compiler.compile(@chapter)
  end

  def compile_block(text)
    compile_block_json(text)
  end

  # Helper method to assert JSON equality by comparing parsed structures
  # This allows testing JSON content without being sensitive to field ordering or formatting
  def assert_json_equal(expected_json, actual_json, message = nil)
    expected_parsed = JSON.parse(expected_json)
    actual_parsed = JSON.parse(actual_json)
    assert_equal(expected_parsed, actual_parsed, message)
  end

  # Helper method to compile inline elements and return AST structure
  def compile_inline_ast(text)
    # Create a minimal paragraph with inline element to get AST structure
    @compiler = ReVIEW::Compiler.new(@builder, ast_mode: true, ast_elements: %i[paragraph])
    @builder.bind(@compiler, @chapter, @builder.instance_variable_get(:@location))

    # Compile a paragraph containing the inline element
    paragraph_content = "Text with #{text} element."
    result = compile_block(paragraph_content)
    json = JSON.parse(result)

    # Extract the inline node from the paragraph
    paragraph = json['children'].find { |child| child['type'] == 'ParagraphNode' }
    inline_node = paragraph['children'].find { |child| child['type'] == 'InlineNode' }

    # Return the inline node as JSON
    JSON.pretty_generate(inline_node)
  end
end
