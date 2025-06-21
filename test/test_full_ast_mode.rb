# frozen_string_literal: true

require_relative 'test_helper'
require 'review/compiler'
require 'review/jsonbuilder'
require 'review/dumper'
require 'stringio'

class TestFullASTMode < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @book = ReVIEW::Book::Base.new
    @book.config = @config
    ReVIEW.logger = ReVIEW::Logger.new(StringIO.new)
  end

  def test_full_ast_mode_simple
    content = <<~REVIEW
      = Test Chapter

      This is a test paragraph.

      //list[sample][Sample Code]{
      puts 'Hello, World!'
      //}
    REVIEW

    dumper = ReVIEW::Dumper.new(mode: :ast)
    temp_file = write_temp_file(content)
    result = dumper.dump_files([temp_file])[temp_file]

    json = JSON.parse(result)
    assert_equal 'DocumentNode', json['type']
    assert_equal 3, json['children'].size

    # Check headline
    assert_equal 'HeadlineNode', json['children'][0]['type']
    assert_equal 1, json['children'][0]['level']
    expected_caption = {
      'type' => 'CaptionNode',
      'location' => { 'filename' => File.basename(temp_file), 'lineno' => 1 },
      'children' => [
        {
          'type' => 'TextNode',
          'content' => 'Test Chapter',
          'location' => { 'filename' => File.basename(temp_file), 'lineno' => 1 }
        }
      ]
    }
    assert_equal expected_caption, json['children'][0]['caption']

    # Check paragraph
    assert_equal 'ParagraphNode', json['children'][1]['type']

    # Check code block
    assert_equal 'CodeBlockNode', json['children'][2]['type']
    assert_equal 'sample', json['children'][2]['id']
    expected_caption = {
      'type' => 'CaptionNode',
      'location' => { 'filename' => File.basename(temp_file), 'lineno' => 5 },
      'children' => [
        {
          'type' => 'TextNode',
          'content' => 'Sample Code',
          'location' => { 'filename' => File.basename(temp_file), 'lineno' => 5 }
        }
      ]
    }
    assert_equal expected_caption, json['children'][2]['caption']
  end

  def test_full_ast_mode_with_inline_elements
    content = <<~REVIEW
      = Chapter

      This paragraph has @<b>{bold} and @<i>{italic} text.
    REVIEW

    dumper = ReVIEW::Dumper.new(mode: :ast)
    temp_file = write_temp_file(content)
    result = dumper.dump_files([temp_file])[temp_file]

    json = JSON.parse(result)

    # Check paragraph with inline elements
    paragraph = json['children'][1]
    assert_equal 'ParagraphNode', paragraph['type']
    assert(paragraph['children'].size > 0, 'Paragraph should have child nodes for inline elements')
  end

  private

  def write_temp_file(content)
    file = Tempfile.new(['test', '.re'])
    file.write(content)
    file.close
    file.path
  end
end
