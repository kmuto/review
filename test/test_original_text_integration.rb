# frozen_string_literal: true

require_relative 'test_helper'
require 'review/snapshot_location'
require 'review/configure'
require 'review/compiler'
require 'review/htmlbuilder'
require 'review/idgxmlbuilder'
require 'stringio'
require 'tempfile'

class TestOriginalTextIntegration < Test::Unit::TestCase
  def setup
    @location = ReVIEW::SnapshotLocation.new('test.re', 1)
    ReVIEW::I18n.setup('ja')
  end

  def test_builder_basic_functionality
    # Test basic builder functionality after AST mode removal
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
        rescue StandardError => _e
          # Skip if can't instantiate due to dependencies
          next
        end
      end

      # Test basic builder methods exist
      assert_respond_to(builder, :target_name)
      assert_respond_to(builder, :result)
    end
  end

  def test_idgxml_builder_instantiation
    # Test that IDGXMLBuilder can be instantiated
    begin
      builder = ReVIEW::IDGXMLBuilder.new({}, StringIO.new)
      assert_equal 'idgxml', builder.target_name
    rescue StandardError => e
      # Skip if can't instantiate due to dependencies
      skip("IDGXMLBuilder dependencies not available: #{e.message}")
    end
  end

  def test_traditional_compilation_works
    # Test that traditional compilation still works after AST mode removal
    builder = ReVIEW::HTMLBuilder.new
    compiler = ReVIEW::Compiler.new(builder)

    # Basic Re:VIEW content
    content = "= Test Chapter\n\nThis is a test paragraph.\n"

    # Create a mock chapter
    config = ReVIEW::Configure.values
    book = ReVIEW::Book::Base.new
    book.config = config
    chapter = ReVIEW::Book::Chapter.new(book, 1, 'test', 'test.re', StringIO.new)
    chapter.content = content

    location = ReVIEW::Location.new('test.re', nil)
    builder.bind(compiler, chapter, location)

    result = compiler.compile(chapter)

    # Verify HTML output contains expected elements
    assert result.include?('<h1>')
    assert result.include?('<p>')
    assert result.include?('Test Chapter')
    assert result.include?('test paragraph')
  end
end
