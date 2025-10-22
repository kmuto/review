# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/tsize_processor'
require 'review/ast/block_node'
require 'review/ast/table_node'
require 'review/ast/table_row_node'
require 'review/ast/table_cell_node'
require 'review/ast/document_node'

class TestTsizeProcessor < Test::Unit::TestCase
  def test_process_tsize_for_latex
    # Create AST with tsize and table
    root = ReVIEW::AST::DocumentNode.new(location: nil)

    # Create tsize block
    tsize_block = ReVIEW::AST::BlockNode.new(
      location: nil,
      block_type: :tsize,
      args: ['10,20,30']
    )
    root.add_child(tsize_block)

    # Create table with 3 columns
    table = ReVIEW::AST::TableNode.new(location: nil, id: 'test')
    row = ReVIEW::AST::TableRowNode.new(location: nil)
    3.times { row.add_child(ReVIEW::AST::TableCellNode.new(location: nil)) }
    table.add_body_row(row)
    root.add_child(table)

    # Process with TsizeProcessor
    ReVIEW::AST::TsizeProcessor.process(root, target_format: 'latex')

    # Verify tsize block was removed
    assert_equal 1, root.children.length
    assert_equal table, root.children.first

    # Verify table has col_spec and cellwidth set
    assert_equal '|p{10mm}|p{20mm}|p{30mm}|', table.col_spec
    assert_equal ['p{10mm}', 'p{20mm}', 'p{30mm}'], table.cellwidth
  end

  def test_process_tsize_with_target_specification
    # Create AST with targeted tsize
    root = ReVIEW::AST::DocumentNode.new(location: nil)

    # Create tsize block with latex target
    tsize_block = ReVIEW::AST::BlockNode.new(
      location: nil,
      block_type: :tsize,
      args: ['|latex,idgxml|10,20,30']
    )
    root.add_child(tsize_block)

    # Create table
    table = ReVIEW::AST::TableNode.new(location: nil, id: 'test')
    row = ReVIEW::AST::TableRowNode.new(location: nil)
    3.times { row.add_child(ReVIEW::AST::TableCellNode.new(location: nil)) }
    table.add_body_row(row)
    root.add_child(table)

    # Process with latex target
    ReVIEW::AST::TsizeProcessor.process(root, target_format: 'latex')

    # Verify table has col_spec set
    assert_equal '|p{10mm}|p{20mm}|p{30mm}|', table.col_spec
  end

  def test_process_tsize_ignores_non_matching_target
    # Create AST with tsize for different target
    root = ReVIEW::AST::DocumentNode.new(location: nil)

    # Create tsize block with html target only
    tsize_block = ReVIEW::AST::BlockNode.new(
      location: nil,
      block_type: :tsize,
      args: ['|html|10,20,30']
    )
    root.add_child(tsize_block)

    # Create table
    table = ReVIEW::AST::TableNode.new(location: nil, id: 'test')
    row = ReVIEW::AST::TableRowNode.new(location: nil)
    3.times { row.add_child(ReVIEW::AST::TableCellNode.new(location: nil)) }
    table.add_body_row(row)
    root.add_child(table)

    # Process with latex target
    ReVIEW::AST::TsizeProcessor.process(root, target_format: 'latex')

    # Verify table uses default col_spec
    assert_nil(table.col_spec)
    assert_nil(table.cellwidth)
  end

  def test_process_complex_tsize_format
    # Create AST with complex tsize format
    root = ReVIEW::AST::DocumentNode.new(location: nil)

    # Create tsize block with complex format
    tsize_block = ReVIEW::AST::BlockNode.new(
      location: nil,
      block_type: :tsize,
      args: ['|l|c|r|']
    )
    root.add_child(tsize_block)

    # Create table
    table = ReVIEW::AST::TableNode.new(location: nil, id: 'test')
    row = ReVIEW::AST::TableRowNode.new(location: nil)
    3.times { row.add_child(ReVIEW::AST::TableCellNode.new(location: nil)) }
    table.add_body_row(row)
    root.add_child(table)

    # Process
    ReVIEW::AST::TsizeProcessor.process(root, target_format: 'latex')

    # Verify
    assert_equal '|l|c|r|', table.col_spec
    assert_equal ['l', 'c', 'r'], table.cellwidth
  end

  def test_process_multiple_tsize_commands
    # Create AST with multiple tsize/table pairs
    root = ReVIEW::AST::DocumentNode.new(location: nil)

    # First tsize and table
    tsize1 = ReVIEW::AST::BlockNode.new(
      location: nil,
      block_type: :tsize,
      args: ['10,20']
    )
    root.add_child(tsize1)

    table1 = ReVIEW::AST::TableNode.new(location: nil, id: 'table1')
    row1 = ReVIEW::AST::TableRowNode.new(location: nil)
    2.times { row1.add_child(ReVIEW::AST::TableCellNode.new(location: nil)) }
    table1.add_body_row(row1)
    root.add_child(table1)

    # Second tsize and table
    tsize2 = ReVIEW::AST::BlockNode.new(
      location: nil,
      block_type: :tsize,
      args: ['30,40,50']
    )
    root.add_child(tsize2)

    table2 = ReVIEW::AST::TableNode.new(location: nil, id: 'table2')
    row2 = ReVIEW::AST::TableRowNode.new(location: nil)
    3.times { row2.add_child(ReVIEW::AST::TableCellNode.new(location: nil)) }
    table2.add_body_row(row2)
    root.add_child(table2)

    # Process
    ReVIEW::AST::TsizeProcessor.process(root, target_format: 'latex')

    # Verify both tsize blocks are removed
    assert_equal 2, root.children.length

    # Verify first table
    assert_equal '|p{10mm}|p{20mm}|', table1.col_spec
    assert_equal ['p{10mm}', 'p{20mm}'], table1.cellwidth

    # Verify second table
    assert_equal '|p{30mm}|p{40mm}|p{50mm}|', table2.col_spec
    assert_equal ['p{30mm}', 'p{40mm}', 'p{50mm}'], table2.cellwidth
  end
end
