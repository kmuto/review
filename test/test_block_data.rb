# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast/block_data'
require 'review/snapshot_location'

class TestBlockData < Test::Unit::TestCase
  include ReVIEW::AST

  def setup
    @location = ReVIEW::SnapshotLocation.new('test.re', 42)
  end

  def test_basic_initialization
    block_data = BlockData.new(name: :list, args: ['id', 'caption'])

    assert_equal :list, block_data.name
    assert_equal ['id', 'caption'], block_data.args
    assert_equal [], block_data.lines
    assert_equal [], block_data.nested_blocks
    assert_nil(block_data.location)
  end

  def test_initialization_with_all_parameters
    nested_block = BlockData.new(name: :note, args: ['warning'])

    block_data = BlockData.new(
      name: :minicolumn,
      args: ['title'],
      lines: ['content line 1', 'content line 2'],
      nested_blocks: [nested_block],
      location: @location
    )

    assert_equal :minicolumn, block_data.name
    assert_equal ['title'], block_data.args
    assert_equal ['content line 1', 'content line 2'], block_data.lines
    assert_equal 1, block_data.nested_blocks.size
    assert_equal nested_block, block_data.nested_blocks.first
    assert_equal @location, block_data.location
  end

  def test_nested_blocks
    # ネストブロックなし
    block_data = BlockData.new(name: :list)
    assert_false(block_data.nested_blocks?)

    # ネストブロックあり
    nested_block = BlockData.new(name: :note)
    block_data_with_nested = BlockData.new(
      name: :minicolumn,
      nested_blocks: [nested_block]
    )
    assert_true(block_data_with_nested.nested_blocks?)
  end

  def test_line_count
    # 行なし
    block_data = BlockData.new(name: :list)
    assert_equal 0, block_data.line_count

    # 行あり
    block_data_with_lines = BlockData.new(
      name: :list,
      lines: ['line1', 'line2', 'line3']
    )
    assert_equal 3, block_data_with_lines.line_count
  end

  def test_content
    # コンテンツなし
    block_data = BlockData.new(name: :list)
    assert_false(block_data.content?)

    # コンテンツあり
    block_data_with_content = BlockData.new(
      name: :list,
      lines: ['content']
    )
    assert_true(block_data_with_content.content?)
  end

  def test_arg_method
    block_data = BlockData.new(
      name: :list,
      args: ['id', 'caption', 'lang']
    )

    # 有効なインデックス
    assert_equal 'id', block_data.arg(0)
    assert_equal 'caption', block_data.arg(1)
    assert_equal 'lang', block_data.arg(2)

    # 無効なインデックス
    assert_nil(block_data.arg(3))
    assert_nil(block_data.arg(-1))
    assert_nil(block_data.arg(nil))
    assert_nil(block_data.arg('invalid'))
  end

  def test_arg_method_with_no_args
    block_data = BlockData.new(name: :list)
    assert_nil(block_data.arg(0))
  end

  def test_to_h
    nested_block = BlockData.new(
      name: :note,
      args: ['warning'],
      lines: ['nested content']
    )

    block_data = BlockData.new(
      name: :minicolumn,
      args: ['title'],
      lines: ['line1', 'line2'],
      nested_blocks: [nested_block],
      location: @location
    )

    hash = block_data.to_h

    assert_equal :minicolumn, hash[:name]
    assert_equal ['title'], hash[:args]
    assert_equal ['line1', 'line2'], hash[:lines]
    assert_equal 1, hash[:nested_blocks].size
    assert_equal @location.to_h, hash[:location]
    assert_equal true, hash[:has_nested_blocks]
    assert_equal 2, hash[:line_count]

    # ネストブロックのハッシュ化もテスト
    nested_hash = hash[:nested_blocks].first
    assert_equal :note, nested_hash[:name]
    assert_equal ['warning'], nested_hash[:args]
  end

  def test_inspect
    block_data = BlockData.new(
      name: :list,
      args: ['id', 'caption'],
      lines: ['line1', 'line2'],
      nested_blocks: [BlockData.new(name: :note)]
    )

    inspect_str = block_data.inspect
    assert_include(inspect_str, 'BlockData')
    assert_include(inspect_str, 'name=list')
    assert_include(inspect_str, 'args=["id", "caption"]')
    assert_include(inspect_str, 'lines=2')
    assert_include(inspect_str, 'nested=1')
  end
end
