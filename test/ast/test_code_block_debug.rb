# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/compiler'
require 'review/ast/json_serializer'
require 'review/book'
require 'review/book/chapter'
require 'json'

class TestCodeBlockDebug < Test::Unit::TestCase
  def setup
    @book = ReVIEW::Book::Base.new
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @config['disable_reference_resolution'] = true
    @book.config = @config

    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)

    @chapter = ReVIEW::Book::Chapter.new(@book, 1, 'debug_chapter', 'debug_chapter.re', StringIO.new)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_code_block_ast_structure
    source = <<~EOS
      = Chapter Title

      //list[test-code][Test Code][ruby]{
      puts @<b>{bold code}
      # Comment with @<fn>{code-fn}
      //}
    EOS

    @chapter.content = source

    # Build AST without builder rendering
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Serialize AST to examine structure
    json_str = ReVIEW::AST::JSONSerializer.serialize(ast_root)
    ast = JSON.parse(json_str)

    # === Code Block AST Structure ===
    result = JSON.pretty_generate(ast)
    expected0 = <<~EXPECTED.chomp
      {
        "type": "DocumentNode",
        "location": {
          "filename": "debug_chapter.re",
          "lineno": 1
        },
        "children": [
          {
            "type": "HeadlineNode",
            "location": {
              "filename": "debug_chapter.re",
              "lineno": 1
            },
            "level": 1,
            "label": null,
            "caption": {
              "type": "CaptionNode",
              "location": {
                "filename": "debug_chapter.re",
                "lineno": 1
              },
              "children": [
                {
                  "type": "TextNode",
                  "location": {
                    "filename": "debug_chapter.re",
                    "lineno": 1
                  },
                  "content": "Chapter Title"
                }
              ]
            }
          },
          {
            "type": "CodeBlockNode",
            "location": {
              "filename": "debug_chapter.re",
              "lineno": 3
            },
            "id": "test-code",
            "lang": "ruby",
            "caption": {
              "type": "CaptionNode",
              "location": {
                "filename": "debug_chapter.re",
                "lineno": 3
              },
              "children": [
                {
                  "type": "TextNode",
                  "location": {
                    "filename": "debug_chapter.re",
                    "lineno": 3
                  },
                  "content": "Test Code"
                }
              ]
            },
            "line_numbers": false,
            "code_type": "list",
            "original_text": "puts @<b>{bold code}\\n# Comment with @<fn>{code-fn}",
            "children": [
              {
                "type": "CodeLineNode",
                "location": {
                  "filename": "debug_chapter.re",
                  "lineno": 3
                },
                "children": [
                  {
                    "type": "TextNode",
                    "location": {
                      "filename": "debug_chapter.re",
                      "lineno": 3
                    },
                    "content": "puts "
                  },
                  {
                    "type": "InlineNode",
                    "location": {
                      "filename": "debug_chapter.re",
                      "lineno": 3
                    },
                    "children": [
                      {
                        "type": "TextNode",
                        "location": {
                          "filename": "debug_chapter.re",
                          "lineno": 3
                        },
                        "content": "bold code"
                      }
                    ],
                    "inline_type": "b",
                    "args": [
                      "bold code"
                    ]
                  }
                ],
                "original_text": "puts @<b>{bold code}"
              },
              {
                "type": "CodeLineNode",
                "location": {
                  "filename": "debug_chapter.re",
                  "lineno": 3
                },
                "children": [
                  {
                    "type": "TextNode",
                    "location": {
                      "filename": "debug_chapter.re",
                      "lineno": 3
                    },
                    "content": "# Comment with "
                  },
                  {
                    "type": "InlineNode",
                    "location": {
                      "filename": "debug_chapter.re",
                      "lineno": 3
                    },
                    "children": [
                      {
                        "type": "ReferenceNode",
                        "location": {
                          "filename": "debug_chapter.re",
                          "lineno": 3
                        },
                        "content": "code-fn"
                      }
                    ],
                    "inline_type": "fn",
                    "args": [
                      "code-fn"
                    ]
                  }
                ],
                "original_text": "# Comment with @<fn>{code-fn}"
              }
            ]
          }
        ],
        "title": "Chapter Title"
      }
    EXPECTED
    assert_equal expected0, result

    # Find code block node
    code_block = ast['children'].find { |node| node['type'] == 'CodeBlockNode' }
    assert_not_nil(code_block)

    # === Code Block Children ===
    result = JSON.pretty_generate(code_block['children'])
    expected = <<~EXPECTED.chomp
      [
        {
          "type": "CodeLineNode",
          "location": {
            "filename": "debug_chapter.re",
            "lineno": 3
          },
          "children": [
            {
              "type": "TextNode",
              "location": {
                "filename": "debug_chapter.re",
                "lineno": 3
              },
              "content": "puts "
            },
            {
              "type": "InlineNode",
              "location": {
                "filename": "debug_chapter.re",
                "lineno": 3
              },
              "children": [
                {
                  "type": "TextNode",
                  "location": {
                    "filename": "debug_chapter.re",
                    "lineno": 3
                  },
                  "content": "bold code"
                }
              ],
              "inline_type": "b",
              "args": [
                "bold code"
              ]
            }
          ],
          "original_text": "puts @<b>{bold code}"
        },
        {
          "type": "CodeLineNode",
          "location": {
            "filename": "debug_chapter.re",
            "lineno": 3
          },
          "children": [
            {
              "type": "TextNode",
              "location": {
                "filename": "debug_chapter.re",
                "lineno": 3
              },
              "content": "# Comment with "
            },
            {
              "type": "InlineNode",
              "location": {
                "filename": "debug_chapter.re",
                "lineno": 3
              },
              "children": [
                {
                  "type": "ReferenceNode",
                  "location": {
                    "filename": "debug_chapter.re",
                    "lineno": 3
                  },
                  "content": "code-fn"
                }
              ],
              "inline_type": "fn",
              "args": [
                "code-fn"
              ]
            }
          ],
          "original_text": "# Comment with @<fn>{code-fn}"
        }
      ]
    EXPECTED
    assert_equal expected, result
  end
end
