# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast/compiler'
require 'review/book'
require 'review/book/chapter'

class TestCodeBlockOriginalText < Test::Unit::TestCase
  def setup
    @book = ReVIEW::Book::Base.new
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book.config = @config

    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)

    @chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test_chapter', 'test_chapter.re', StringIO.new)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_code_block_original_text_preservation
    source = <<~EOS
      = Chapter Title

      //list[test-code][Test Code][ruby]{
      puts @<b>{bold code}
      # Comment with @<fn>{code-fn}
      normal line
      //}
    EOS

    @chapter.content = source

    # Build AST without builder rendering
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Find code block node
    code_block = ast_root.children.find { |node| node.class.name.include?('CodeBlockNode') }
    assert_not_nil(code_block)

    # Test original_text preservation
    expected_original = "puts @<b>{bold code}\n# Comment with @<fn>{code-fn}\nnormal line"
    assert_equal expected_original, code_block.original_text

    # Test original_lines method
    expected_lines = [
      'puts @<b>{bold code}',
      '# Comment with @<fn>{code-fn}',
      'normal line'
    ]
    assert_equal expected_lines, code_block.original_lines

    # Test processed_lines method (should reconstruct from AST)
    processed = code_block.processed_lines
    assert_equal 3, processed.size
    assert_equal 'puts @<b>{bold code}', processed[0]
    assert_equal '# Comment with @<fn>{code-fn}', processed[1]
    assert_equal 'normal line', processed[2]

    puts "Original text: #{code_block.original_text.inspect}"
    puts "Original lines: #{code_block.original_lines.inspect}"
    puts "Processed lines: #{code_block.processed_lines.inspect}"
  end
end
