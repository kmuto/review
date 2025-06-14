# frozen_string_literal: true

require 'test_helper'
require 'review/astbuilder'
require 'review/configure'
require 'review/book'
require 'review/compiler'
require 'stringio'

class TestASTBuilderSimple < Test::Unit::TestCase
  def setup
    @builder = ReVIEW::ASTBuilder.new
    # Initialize document structure manually for testing
    @builder.instance_variable_set(:@document, {
                                     'type' => 'document',
                                     'children' => []
                                   })
    @builder.instance_variable_set(:@current_container, @builder.instance_variable_get(:@document))
    @builder.instance_variable_set(:@stack, [])
  end

  def test_basic_document_structure
    result = @builder.result
    assert_equal 'document', result['type']
    assert_equal [], result['children']
  end

  def test_headline_creation
    @builder.headline(1, 'intro', 'Introduction')
    result = @builder.result

    assert_equal 1, result['children'].size
    headline = result['children'][0]
    assert_equal 'heading', headline['type']
    assert_equal 1, headline['attrs']['level']
    assert_equal 'intro', headline['attrs']['label']
    assert_equal 'Introduction', headline['value']
  end

  def test_paragraph_creation
    @builder.paragraph(['This is a test paragraph.'])
    result = @builder.result

    assert_equal 1, result['children'].size
    paragraph = result['children'][0]
    assert_equal 'paragraph', paragraph['type']
    assert_equal 'This is a test paragraph.', paragraph['value']
  end

  def test_list_creation
    @builder.list(['line 1', 'line 2'], 'sample', 'Sample List', 'ruby')
    result = @builder.result

    assert_equal 1, result['children'].size
    list = result['children'][0]
    assert_equal 'list', list['type']
    assert_equal 'sample', list['attrs']['id']
    assert_equal 'Sample List', list['attrs']['caption']
    assert_equal 'ruby', list['attrs']['language']
    assert_equal 2, list['children'].size
  end

  def test_nested_structure
    @builder.headline(1, nil, 'Chapter')
    @builder.paragraph(['First paragraph'])
    @builder.paragraph(['Second paragraph'])

    result = @builder.result
    assert_equal 3, result['children'].size
    assert_equal 'heading', result['children'][0]['type']
    assert_equal 'paragraph', result['children'][1]['type']
    assert_equal 'paragraph', result['children'][2]['type']
  end

  def test_inline_node_creation
    inline_node = @builder.send(:create_inline_node, 'b', 'bold text')
    assert_equal 'inline_command', inline_node['type']
    assert_equal 'b', inline_node['attrs']['command']
    assert_equal 'bold text', inline_node['value']
  end
end
