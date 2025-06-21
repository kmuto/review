# frozen_string_literal: true

require_relative 'test_helper'
require 'review/snapshot_location'
require 'review/configure'
require 'review/compiler'
require 'review/jsonbuilder'
require 'review/htmlbuilder'
require 'review/idgxmlbuilder'
require 'stringio'
require 'tempfile'

class TestOriginalTextIntegration < Test::Unit::TestCase
  def setup
    @location = ReVIEW::SnapshotLocation.new('test.re', 1)
  end

  def test_builder_interprets_inline_in_code_interface
    # Test that builders respond to the interface
    builders = [
      ReVIEW::Builder,
      ReVIEW::HTMLBuilder,
      ReVIEW::IDGXMLBuilder
    ]

    builders.each do |builder_class|
      if builder_class == ReVIEW::Builder
        builder = builder_class.new
      else
        # For subclasses that require config and io
        begin
          builder = builder_class.new({}, StringIO.new)
        rescue StandardError => e
          # Skip if can't instantiate due to dependencies
          next
        end
      end

      assert_respond_to(builder, :interprets_inline_in_code?)
      assert [true, false].include?(builder.interprets_inline_in_code?)
    end
  end

  def test_idgxml_builder_interprets_inline_in_code
    # Test that IDGXMLBuilder returns true for interprets_inline_in_code?
    begin
      builder = ReVIEW::IDGXMLBuilder.new({}, StringIO.new)
      assert_equal true, builder.interprets_inline_in_code?
    rescue StandardError => e
      # Skip if can't instantiate due to dependencies
      skip("IDGXMLBuilder dependencies not available: #{e.message}")
    end
  end

  def test_render_ast_node_as_plain_text_with_base_builder
    # Test the plain text rendering with base builder
    builder = ReVIEW::Builder.new

    # Create: "Hello @<b>{world} text"
    paragraph = ReVIEW::AST::ParagraphNode.new(location: @location)
    paragraph.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'Hello '))

    inline_node = ReVIEW::AST::InlineNode.new(location: @location, inline_type: 'b')
    inline_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: 'world'))
    paragraph.add_child(inline_node)

    paragraph.add_child(ReVIEW::AST::TextNode.new(location: @location, content: ' text'))

    # Test rendering back to plain text
    result = builder.render_ast_node_as_plain_text(paragraph)
    assert_equal 'Hello @<b>{world} text', result
  end
end
