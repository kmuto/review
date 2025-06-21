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
    result = ProjectTestHelper.compile_with_mode('html', ast_mode: 'off', debug: false)

    assert_true(result[:success], 'Compilation should succeed in traditional mode')
    assert_operator(result[:output].length, :>, 0, 'Should produce output')
  end

  def test_compilation_ast_auto_mode
    # Skip this heavy test for normal runs - only run with FULL_INTEGRATION_TEST=1
    pend 'Use FULL_INTEGRATION_TEST=1 to run heavy integration tests' unless ENV['FULL_INTEGRATION_TEST']
    
    result = ProjectTestHelper.compile_with_mode('html', ast_mode: 'auto', debug: true)

    assert_true(result[:success], 'Compilation should succeed in auto mode')
    assert_operator(result[:output].length, :>, 0, 'Should produce output')

    # Check for AST debug output
    if result[:output].include?('DEBUG: ASTCompiler')
      assert_match(/AST mode/, result[:output], 'Should show AST mode information')
    end
  end

  def test_compilation_ast_full_mode
    # Skip this heavy test for normal runs - only run with FULL_INTEGRATION_TEST=1
    pend 'Use FULL_INTEGRATION_TEST=1 to run heavy integration tests' unless ENV['FULL_INTEGRATION_TEST']
    
    result = ProjectTestHelper.compile_with_mode('html', ast_mode: 'full', debug: true)

    assert_true(result[:success], 'Compilation should succeed in full AST mode')
    assert_operator(result[:output].length, :>, 0, 'Should produce output')
  end

  def test_compilation_all_formats
    # Skip this heavy test for normal runs - only run with FULL_INTEGRATION_TEST=1
    pend 'Use FULL_INTEGRATION_TEST=1 to run heavy integration tests' unless ENV['FULL_INTEGRATION_TEST']
    
    results = ProjectTestHelper.test_all_formats

    %w[html latex json].each do |format|
      assert_true(results[format][:success], "#{format.upcase} compilation should succeed")
    end
  end

  def test_cross_references
    # Skip this heavy test for normal runs - only run with FULL_INTEGRATION_TEST=1
    pend 'Use FULL_INTEGRATION_TEST=1 to run heavy integration tests' unless ENV['FULL_INTEGRATION_TEST']
    
    result = ProjectTestHelper.test_cross_references

    assert_true(result[:success], 'Cross-reference compilation should succeed')
    # Cross-references should work in AST mode
    assert_not_match(/undefined reference/, result[:output], 'Should not have undefined references')
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
