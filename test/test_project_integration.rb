# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'project_test_helper'

class ProjectIntegrationTest < Test::Unit::TestCase
  def setup
    ProjectTestHelper.setup_test_environment
  end

  def test_project_structure
    structure = ProjectTestHelper.verify_project_structure

    assert_true(structure[:config_exists], 'config.yml should exist')
    assert_true(structure[:catalog_exists], 'catalog.yml should exist')
    assert_true(structure[:images_dir], 'images directory should exist')
    assert_true(structure[:sty_dir], 'sty directory should exist')
    assert_operator(structure[:re_files].size, :>, 5, 'Should have multiple Re:VIEW files')
  end

  def test_compilation_traditional_mode
    result = ProjectTestHelper.compile_traditional('html', debug: false)

    assert_true(result[:success], 'Traditional compilation should succeed')
    assert_operator(result[:output].length, :>, 0, 'Should produce output')
    assert_match(/<h1>/, result[:output], 'Should contain HTML headline tags')
  end

  def test_compilation_ast_renderer_mode
    result = ProjectTestHelper.compile_ast_renderer('html', debug: false)

    assert_true(result[:success], 'AST/Renderer compilation should succeed')
    assert_operator(result[:output].length, :>, 0, 'Should produce output')
    assert_match(/<h1>/, result[:output], 'Should contain HTML headline tags')
  end

  def test_compilation_all_formats_traditional
    results = ProjectTestHelper.test_all_formats_traditional

    %w[html latex].each do |format|
      assert_true(results[format][:success], "Traditional #{format.upcase} compilation should succeed")
    end
  end

  def test_compilation_all_formats_ast_renderer
    results = ProjectTestHelper.test_all_formats_ast_renderer

    %w[html].each do |format| # Start with HTML, add LaTeX later
      assert_true(results[format][:success], "AST/Renderer #{format.upcase} compilation should succeed")
    end
  end

  def test_cross_references_traditional
    result = ProjectTestHelper.test_cross_references_traditional

    assert_true(result[:success], 'Traditional cross-reference compilation should succeed')
    assert_not_match(/undefined reference/, result[:output], 'Should not have undefined references')
  end

  def test_cross_references_ast_renderer
    result = ProjectTestHelper.test_cross_references_ast_renderer

    assert_true(result[:success], 'AST/Renderer cross-reference compilation should succeed')
    assert_not_match(/undefined reference/, result[:output], 'Should not have undefined references')
  end

  def test_output_comparison
    # Compare output between traditional and AST/Renderer modes
    traditional_result = ProjectTestHelper.compile_traditional('html', debug: false)
    ast_result = ProjectTestHelper.compile_ast_renderer('html', debug: false)

    assert_true(traditional_result[:success], 'Traditional compilation should succeed')
    assert_true(ast_result[:success], 'AST/Renderer compilation should succeed')

    # Both should produce valid HTML
    [traditional_result[:output], ast_result[:output]].each do |output|
      assert_match(/<html/, output, 'Should contain HTML document structure')
      assert_match(/<h1>/, output, 'Should contain headline tags')
      assert_match(/<p>/, output, 'Should contain paragraph tags')
    end
  end

  def test_available_files
    files = ProjectTestHelper.available_re_files

    expected_files = %w[
      basic_elements.re
      comprehensive_test.re
      lists.re
      tables_images.re
    ]

    expected_files.each do |file|
      assert_includes(files, file, "Should include #{file}")
    end
  end
end
