#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'ast_builder_compatibility_helper'
require 'review/htmlbuilder'

class ASTHTMLCompatibilityTest < Test::Unit::TestCase
  include ASTBuilderCompatibilityHelper

  def setup
    setup_compatibility_test
  end

  def test_html_all_verification_files
    test_all_verification_files(ReVIEW::HTMLBuilder)
  end

  def test_html_structure_consistency
    test_structure_consistency(ReVIEW::HTMLBuilder)
  end

  def test_html_performance_comparison
    # Skip performance test for normal runs - only run with FULL_INTEGRATION_TEST=1
    pend 'Use FULL_INTEGRATION_TEST=1 to run performance tests' unless ENV['FULL_INTEGRATION_TEST']
    
    test_performance_comparison(ReVIEW::HTMLBuilder)
  end

  def test_html_validation
    # Test that generated HTML is well-formed
    puts "\n=== HTML Validation Test ==="

    complex_file = File.join(@fixtures_dir, 'complex_structure.re')
    content = File.read(complex_file)

    test_modes.each do |mode_name, _|
      output = compile_with_builder(content, ReVIEW::HTMLBuilder, mode_name)

      # Basic HTML validation
      assert_html_wellformed(mode_name, output)
    end
  end

  private

  def file_extension
    'html'
  end

  # Analyze HTML structure for comparison
  def analyze_html_structure(html_output)
    structure = {}

    # Count major HTML elements
    structure[:headings] = html_output.scan(/<h[1-6][^>]*>/).count
    structure[:paragraphs] = html_output.scan(/<p[^>]*>/).count
    structure[:lists] = html_output.scan(/<[uo]l[^>]*>/).count
    structure[:list_items] = html_output.scan(/<li[^>]*>/).count
    structure[:tables] = html_output.scan(/<table[^>]*>/).count
    structure[:images] = html_output.scan(/<img[^>]*>/).count
    structure[:links] = html_output.scan(/<a[^>]*>/).count
    structure[:code_blocks] = html_output.scan(/<pre[^>]*>/).count
    structure[:inline_code] = html_output.scan(/<code[^>]*>/).count
    structure[:definition_lists] = html_output.scan(/<dl[^>]*>/).count

    # Count total tags
    structure[:total_tags] = html_output.scan(%r{<[^/][^>]*>}).count

    # Analyze document structure
    structure[:has_html_tag] = html_output.include?('<html')
    structure[:has_head_tag] = html_output.include?('<head')
    structure[:has_body_tag] = html_output.include?('<body')
    structure[:has_title_tag] = html_output.include?('<title')

    structure
  end

  # Check if HTML structures are equivalent
  def structures_equivalent?(struct1, struct2)
    # Check major structural elements
    major_elements = %i[headings paragraphs lists tables images definition_lists]

    major_elements.all? do |element|
      struct1[element] == struct2[element]
    end
  end

  # Assert that essential HTML elements are preserved
  def assert_html_elements_preserved(basename, traditional_html, hybrid_html)
    essential_elements = %i[headings paragraphs lists tables images]

    essential_elements.each do |element|
      assert_equal traditional_html[element], hybrid_html[element],
                   "#{element} count differs for #{basename}. Traditional: #{traditional_html[element]}, Hybrid: #{hybrid_html[element]}"
    end
  end

  # Basic HTML well-formedness check
  def assert_html_wellformed(mode_name, html_output)
    # Check for basic HTML document structure
    if html_output.include?('<html')
      assert html_output.include?('</html>'), "#{mode_name}: Missing closing </html> tag"
    end

    if html_output.include?('<head')
      assert html_output.include?('</head>'), "#{mode_name}: Missing closing </head> tag"
    end

    if html_output.include?('<body')
      assert html_output.include?('</body>'), "#{mode_name}: Missing closing </body> tag"
    end

    # Check for properly nested list elements
    ul_count = html_output.scan(/<ul[^>]*>/).count
    ul_close_count = html_output.scan('</ul>').count
    assert_equal ul_count, ul_close_count, "#{mode_name}: Unmatched <ul> tags"

    ol_count = html_output.scan(/<ol[^>]*>/).count
    ol_close_count = html_output.scan('</ol>').count
    assert_equal ol_count, ol_close_count, "#{mode_name}: Unmatched <ol> tags"

    # Check for properly nested table elements
    table_count = html_output.scan(/<table[^>]*>/).count
    table_close_count = html_output.scan('</table>').count
    assert_equal table_count, table_close_count, "#{mode_name}: Unmatched <table> tags"
  end

  # Count inline HTML elements
  def count_html_inline_elements(html_output)
    inline_elements = %w[b i strong em code tt kbd samp var sub sup small big u s strike del ins span a]

    count = 0
    inline_elements.each do |tag|
      count += html_output.scan(/<#{tag}(\s[^>]*)?>/).count
    end

    count
  end

  # Override structure analysis for HTML-specific details
  def analyze_structure(output)
    base_structure = super
    html_structure = analyze_html_structure(output)
    base_structure.merge(html_structure)
  end

  # Report HTML-specific structure differences
  def report_structure_differences(basename, traditional_structure, hybrid_structure)
    super

    html_elements = %i[headings paragraphs lists tables images]
    html_elements.each do |element|
      if traditional_structure[element] != hybrid_structure[element]
        puts "    #{element}: Traditional=#{traditional_structure[element]}, Hybrid=#{hybrid_structure[element]}"
      end
    end
  end
end
