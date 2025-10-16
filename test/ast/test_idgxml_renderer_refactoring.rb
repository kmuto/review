# frozen_string_literal: true

require 'test-unit'
require 'review/book'
require 'review/ast/compiler'
require 'review/renderer/idgxml_renderer'

# Test cases for IdgxmlRenderer refactoring improvements
# Tests ListContext, solve_nest decomposition, and improved list handling
class IdgxmlRendererRefactoringTest < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.new
    @book = ReVIEW::Book::Base.new('.')
    @book.config = @config
    @chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.re')
    @renderer = ReVIEW::Renderer::IdgxmlRenderer.new(@chapter)
  end

  def test_list_context_tag_name_depth1
    context = ReVIEW::Renderer::ListContext.new(:ul, 1)
    assert_equal 'ul', context.tag_name
  end

  def test_list_context_tag_name_depth2
    context = ReVIEW::Renderer::ListContext.new(:ul, 2)
    assert_equal 'ul2', context.tag_name
  end

  def test_list_context_tag_name_depth3
    context = ReVIEW::Renderer::ListContext.new(:ol, 3)
    assert_equal 'ol3', context.tag_name
  end

  def test_list_context_opening_marker_depth1
    context = ReVIEW::Renderer::ListContext.new(:ul, 1)
    assert_equal '', context.opening_marker
  end

  def test_list_context_opening_marker_depth2
    context = ReVIEW::Renderer::ListContext.new(:ul, 2)
    assert_equal ReVIEW::Renderer::IdgxmlRenderer::IDGXML_LIST_NEST_UL_START, context.opening_marker
  end

  def test_list_context_closing_marker_depth1
    context = ReVIEW::Renderer::ListContext.new(:ol, 1)
    assert_equal '', context.closing_marker
  end

  def test_list_context_closing_marker_depth2
    context = ReVIEW::Renderer::ListContext.new(:ol, 2)
    assert_equal ReVIEW::Renderer::IdgxmlRenderer::IDGXML_LIST_NEST_OL_END, context.closing_marker
  end

  def test_list_context_item_close_tag_ul
    context = ReVIEW::Renderer::ListContext.new(:ul, 1)
    assert_equal '</li>', context.item_close_tag
  end

  def test_list_context_item_close_tag_ol
    context = ReVIEW::Renderer::ListContext.new(:ol, 2)
    assert_equal '</li>', context.item_close_tag
  end

  def test_list_context_item_close_tag_dl
    context = ReVIEW::Renderer::ListContext.new(:dl, 1)
    assert_equal '</dd>', context.item_close_tag
  end

  def test_list_context_mark_nested_content
    context = ReVIEW::Renderer::ListContext.new(:ul, 1)
    assert_equal false, context.has_nested_content
    context.mark_nested_content
    assert_equal true, context.has_nested_content
  end

  def test_solve_nest_removes_opening_markers
    # Test that opening markers are properly removed
    input = '<ul2>' + ReVIEW::Renderer::IdgxmlRenderer::IDGXML_LIST_NEST_UL_START + '<li>item</li></ul2>'
    expected = '<ul2><li>item</li></ul2>'
    result = @renderer.send(:solve_nest, input)
    assert_equal expected, result
  end

  def test_solve_nest_merges_consecutive_ul
    # Test that consecutive ul lists are merged
    input = '<ul><li>item1</li></ul><ul><li>item2</li></ul>'
    expected = '<ul><li>item1</li><li>item2</li></ul>'
    result = @renderer.send(:solve_nest, input)
    assert_equal expected, result
  end

  def test_solve_nest_merges_consecutive_ol
    # Test that consecutive ol lists are merged
    input = '<ol><li aid:pstyle="ol-item" olnum="1" num="1">item1</li></ol><ol><li aid:pstyle="ol-item" olnum="2" num="2">item2</li></ol>'
    expected = '<ol><li aid:pstyle="ol-item" olnum="1" num="1">item1</li><li aid:pstyle="ol-item" olnum="2" num="2">item2</li></ol>'
    result = @renderer.send(:solve_nest, input)
    assert_equal expected, result
  end

  def test_solve_nest_merges_consecutive_dl
    # Test that consecutive dl lists are merged
    input = '<dl><dt>term1</dt><dd>def1</dd></dl><dl><dt>term2</dt><dd>def2</dd></dl>'
    expected = '<dl><dt>term1</dt><dd>def1</dd><dt>term2</dt><dd>def2</dd></dl>'
    result = @renderer.send(:solve_nest, input)
    assert_equal expected, result
  end

  def test_solve_nest_with_nested_markers
    # Test that nested list markers are properly handled
    marker_start = ReVIEW::Renderer::IdgxmlRenderer::IDGXML_LIST_NEST_UL_START
    marker_end = ReVIEW::Renderer::IdgxmlRenderer::IDGXML_LIST_NEST_UL_END
    input = "<ul><li>item1<ul2>#{marker_start}<li>nested</li>#{marker_end}</ul2></li></ul>"
    # After solve_nest, markers should be removed
    result = @renderer.send(:solve_nest, input)
    assert_not_include(result, marker_start)
    assert_not_include(result, marker_end)
  end

  def test_solve_nest_step_by_step
    # Test each step of solve_nest independently
    marker_start = ReVIEW::Renderer::IdgxmlRenderer::IDGXML_LIST_NEST_UL_START
    marker_end = ReVIEW::Renderer::IdgxmlRenderer::IDGXML_LIST_NEST_UL_END
    merge_marker = ReVIEW::Renderer::IdgxmlRenderer::IDGXML_LIST_MERGE_MARKER

    # Step 1: remove_opening_markers
    input1 = "<ul2>#{marker_start}<li>item</li></ul2>"
    result1 = @renderer.send(:remove_opening_markers, input1)
    assert_equal '<ul2><li>item</li></ul2>', result1

    # Step 2: convert_to_merge_markers
    input2 = "<ul2><li>item</li>#{marker_end}</ul2>"
    result2 = @renderer.send(:convert_to_merge_markers, input2)
    assert_include(result2, merge_marker)

    # Step 3: merge_lists_with_markers
    input3 = "</ul>#{merge_marker}<ul>"
    result3 = @renderer.send(:merge_lists_with_markers, input3)
    assert_equal '', result3

    # Step 4: merge_toplevel_lists
    # Note: This pattern only matches when there's specific structure
    input4 = '</li></ul><ul><li'
    result4 = @renderer.send(:merge_toplevel_lists, input4.delete("\n"))
    assert_equal '</li><li', result4
  end

  def test_render_list_with_context_ul
    # Create a simple ul list AST
    list_node = ReVIEW::AST::ListNode.new(location: nil)
    list_node.list_type = :ul
    item1 = ReVIEW::AST::ListItemNode.new(location: nil)
    text1 = ReVIEW::AST::TextNode.new(location: nil, content: 'Item 1')
    para1 = ReVIEW::AST::ParagraphNode.new(location: nil)
    para1.children = [text1]
    item1.children = [para1]
    list_node.children = [item1]

    result = @renderer.send(:render_list, list_node, :ul)
    assert_include(result, '<ul>')
    assert_include(result, '</ul>')
    assert_include(result, '<li aid:pstyle="ul-item">')
  end

  def test_increment_and_decrement_list_depth
    # Test depth counter management
    initial_ul_depth = @renderer.instance_variable_get(:@ul_depth)

    depth1 = @renderer.send(:increment_list_depth, :ul)
    assert_equal initial_ul_depth + 1, depth1

    depth2 = @renderer.send(:increment_list_depth, :ul)
    assert_equal initial_ul_depth + 2, depth2

    @renderer.send(:decrement_list_depth, :ul)
    assert_equal initial_ul_depth + 1, @renderer.instance_variable_get(:@ul_depth)

    @renderer.send(:decrement_list_depth, :ul)
    assert_equal initial_ul_depth, @renderer.instance_variable_get(:@ul_depth)
  end

  def test_with_list_context_restores_state
    # Test that with_list_context properly manages and restores state
    initial_context = @renderer.instance_variable_get(:@current_list_context)
    initial_depth = @renderer.instance_variable_get(:@ul_depth)

    @renderer.send(:with_list_context, :ul) do |context|
      # Inside the block, context should be set
      assert_not_nil(context)
      assert_equal :ul, context.list_type
      assert_equal @renderer.instance_variable_get(:@current_list_context), context
    end

    # After the block, state should be restored
    assert_equal initial_context, @renderer.instance_variable_get(:@current_list_context)
    assert_equal initial_depth, @renderer.instance_variable_get(:@ul_depth)
  end
end
