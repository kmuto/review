# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/dumper'
require 'tmpdir'
require 'json'

class TestDumper < Test::Unit::TestCase
  def setup
    @tmpdir = Dir.mktmpdir
    @config = ReVIEW::Configure.values
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def create_review_file(content, filename = 'test.re')
    path = File.join(@tmpdir, filename)
    File.write(path, content)
    path
  end

  def test_dump_ast_mode
    content = <<~REVIEW
      = Test Chapter

      This is a test paragraph.

      //list[sample][Sample Code]{
      puts 'Hello, World!'
      //}
    REVIEW

    path = create_review_file(content)
    dumper = ReVIEW::AST::Dumper.new
    result = dumper.dump_file(path)

    json = JSON.parse(result)
    assert_equal 'DocumentNode', json['type']
    assert_equal 'Test Chapter', json['title']
    assert_equal 3, json['children'].size

    # Check headline
    assert_equal 'HeadlineNode', json['children'][0]['type']
    assert_equal 1, json['children'][0]['level']
    expected_caption = {
      'type' => 'CaptionNode',
      'location' => { 'filename' => 'test.re', 'lineno' => 1 },
      'children' => [
        {
          'type' => 'TextNode',
          'content' => 'Test Chapter',
          'location' => { 'filename' => 'test.re', 'lineno' => 1 }
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
      'location' => { 'filename' => 'test.re', 'lineno' => 5 },
      'children' => [
        {
          'type' => 'TextNode',
          'content' => 'Sample Code',
          'location' => { 'filename' => 'test.re', 'lineno' => 5 }
        }
      ]
    }
    assert_equal expected_caption, json['children'][2]['caption']
  end

  def test_dump_with_compact_options
    content = "= Test\n\nParagraph"
    path = create_review_file(content)

    options = ReVIEW::AST::JSONSerializer::Options.new
    options.pretty = false
    options.include_location = false

    dumper = ReVIEW::AST::Dumper.new(serializer_options: options)
    result = dumper.dump_file(path)

    # Should be compact JSON
    assert_not_include(result, "\n")

    json = JSON.parse(result)
    # Should not have location
    assert_nil(json['location'])
  end

  def test_dump_multiple_files
    content1 = "= Chapter 1\n\nContent 1"
    content2 = "= Chapter 2\n\nContent 2"

    path1 = create_review_file(content1, 'ch01.re')
    path2 = create_review_file(content2, 'ch02.re')

    dumper = ReVIEW::AST::Dumper.new
    results = dumper.dump_files([path1, path2])

    assert_equal 2, results.size
    assert_include(results, path1)
    assert_include(results, path2)

    json1 = JSON.parse(results[path1])
    json2 = JSON.parse(results[path2])

    assert_equal 'Chapter 1', json1['title']
    assert_equal 'Chapter 2', json2['title']
  end

  def test_dump_nonexistent_file
    dumper = ReVIEW::AST::Dumper.new
    assert_raise(ReVIEW::FileNotFound) do
      dumper.dump_file('/nonexistent/file.re')
    end
  end
end
