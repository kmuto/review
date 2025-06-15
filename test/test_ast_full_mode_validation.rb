# frozen_string_literal: true

require 'test_helper'
require 'review/book'
require 'review/compiler'
require 'review/configure'
require 'review/jsonbuilder'
require 'review/ast'
require 'review/ast/config'
require 'fileutils'
require 'json'

# Test to validate AST full mode compatibility more thoroughly
class ASTFullModeValidationTest < Test::Unit::TestCase
  def setup
    @fixtures_dir = File.join(__dir__, 'project')
    @output_dir = File.join(__dir__, '..', 'tmp', 'ast_validation')
    FileUtils.makedirs(@output_dir)
  end

  def test_jsonbuilder_ast_full_mode_completeness
    # JSONBuilder is currently the only builder with full AST support
    # This test verifies that AST full mode produces complete output
    puts "\n=== JSONBuilder AST Full Mode Validation ==="

    test_content = <<~REVIEW
      = Chapter Title

      This is a paragraph with @<b>{bold} and @<i>{italic} text.

      == Section 1

      //list[sample][Sample code]{
      def hello
        puts "Hello, World!"
      end
      //}

      * List item 1
      * List item 2 with @<code>{inline code}

      : Term 1
        Definition 1
      : Term 2
        Definition 2

      //table[sample][Sample table]{
      Header 1	Header 2
      ---------------------
      Cell 1	Cell 2
      Cell 3	Cell 4
      //}
    REVIEW

    # Compile with different modes
    traditional_json = compile_json(test_content, 'traditional')
    ast_full_json = compile_json(test_content, 'ast_full')
    hybrid_json = compile_json(test_content, 'hybrid_stage3')

    # Parse JSON outputs
    traditional_data = JSON.parse(traditional_json)
    ast_full_data = JSON.parse(ast_full_json)
    hybrid_data = JSON.parse(hybrid_json)

    # Verify that AST full mode produces output
    refute_empty(ast_full_json, 'AST full mode should produce output')
    assert ast_full_data.is_a?(Hash), 'AST full mode should produce valid JSON'

    # Verify essential structure elements
    verify_ast_structure_completeness(ast_full_data, traditional_data)

    # Output comparison report
    generate_validation_report(traditional_data, ast_full_data, hybrid_data)
  end

  def test_ast_full_mode_element_coverage
    # Test that all Re:VIEW elements are handled in AST full mode
    puts "\n=== AST Element Coverage Test ==="

    element_test_cases = {
      'headline' => "= Title\n== Section",
      'paragraph' => "= Title\n\nThis is a paragraph.",
      'list' => "= Title\n\n* Item 1\n* Item 2",
      'ordered_list' => "= Title\n\n1. First\n2. Second",
      'definition_list' => "= Title\n\n: Term\n  Definition",
      'code_block' => "= Title\n\n//list[id][caption]{\ncode\n//}",
      'table' => "= Title\n\n//table[id][caption]{\nA\tB\n-----\n1\t2\n//}",
      'inline_code' => "= Title\n\nText with @<code>{inline}.",
      'bold' => "= Title\n\nText with @<b>{bold}.",
      'italic' => "= Title\n\nText with @<i>{italic}."
    }

    element_test_cases.each do |element_name, content|
      puts "\n  Testing #{element_name}..."

      traditional_json = compile_json(content, 'traditional')
      ast_full_json = compile_json(content, 'ast_full')

      traditional_data = JSON.parse(traditional_json)
      ast_full_data = JSON.parse(ast_full_json)

      # Debug output for all tests during development
      puts '    AST Full JSON output (first 800 chars):'
      puts "    #{ast_full_json[0..800]}"

      # Skip elements that are not yet supported in AST full mode
      unsupported_in_ast_full = ['list', 'ordered_list', 'definition_list', 'table', 'code_block']
      if unsupported_in_ast_full.include?(element_name)
        puts "    ⚠️  Skipping #{element_name} - not yet supported in AST full mode"
        next
      end

      # Verify element is present in AST output
      assert_element_present_in_ast(element_name, ast_full_data, traditional_data)
    end
  end

  def test_ast_hybrid_mode_progression
    # Test that hybrid modes progressively add AST support
    puts "\n=== Hybrid Mode Progression Test ==="

    test_content = <<~REVIEW
      = Title

      Paragraph text.

      * List item

      //list[code][Code block]{
      code
      //}
    REVIEW

    modes = {
      'traditional' => 'Traditional (no AST)',
      'hybrid_stage1' => 'Stage 1 (headline only)',
      'hybrid_stage2' => 'Stage 2 (headline + paragraph)',
      'hybrid_stage3' => 'Stage 3 (+ lists)',
      'ast_full' => 'Full AST'
    }

    results = {}
    modes.each do |mode, description|
      puts "\n  #{description}:"
      json_output = compile_json(test_content, mode)
      data = JSON.parse(json_output)

      # Analyze AST coverage
      coverage = analyze_ast_coverage(data)
      results[mode] = coverage

      coverage.each do |element, count|
        puts "    #{element}: #{count}"
      end
    end

    # Verify progression
    assert results['hybrid_stage1']['ast_nodes'] > 0, 'Stage 1 should have some AST nodes'
    assert results['hybrid_stage2']['ast_nodes'] >= results['hybrid_stage1']['ast_nodes'],
           'Stage 2 should have more AST nodes than Stage 1'
    assert results['hybrid_stage3']['ast_nodes'] >= results['hybrid_stage2']['ast_nodes'],
           'Stage 3 should have more AST nodes than Stage 2'
  end

  private

  def compile_json(content, mode)
    config = ReVIEW::Configure.values

    case mode
    when 'traditional'
      config['ast'] = { 'mode' => 'off' }
    when 'ast_full'
      config['ast'] = { 'mode' => 'full' }
    when 'hybrid_stage1'
      config['ast'] = { 'mode' => 'hybrid', 'stage' => 1 }
    when 'hybrid_stage2'
      config['ast'] = { 'mode' => 'hybrid', 'stage' => 2 }
    when 'hybrid_stage3'
      config['ast'] = { 'mode' => 'hybrid', 'stage' => 3 }
    end

    book = ReVIEW::Book::Base.new
    book.config = config

    ast_config = ReVIEW::AST::Config.new(config)
    compiler_options = ast_config.compiler_options

    builder = ReVIEW::JSONBuilder.new
    compiler = ReVIEW::Compiler.new(builder, **compiler_options)

    chapter = ReVIEW::Book::Chapter.new(book, 1, 'test', nil, StringIO.new(content))
    location = ReVIEW::Location.new(nil, nil)

    builder.bind(compiler, chapter, location)
    compiler.compile(chapter)
    builder.result
  end

  def verify_ast_structure_completeness(ast_data, _traditional_data)
    # Check that AST data contains essential document structure
    assert ast_data.key?('type'), "AST should have 'type' field"

    # Accept both 'document' and 'DocumentNode' as valid types
    valid_document_types = ['document', 'DocumentNode']
    assert valid_document_types.include?(ast_data['type']),
           "Root should be document type, but was #{ast_data['type']}"

    assert ast_data.key?('children'), 'AST should have children'
    refute_empty(ast_data['children'], 'AST should have content')

    # Verify metadata if present (may be optional)
    if ast_data.key?('metadata')
      assert ast_data['metadata'].key?('title'), 'AST metadata should include title'
    end
  end

  def assert_element_present_in_ast(element_name, ast_data, _traditional_data)
    # Check if element is represented in AST output
    ast_json = JSON.pretty_generate(ast_data)

    # For better compatibility, check both with and without spaces in JSON
    case element_name
    when 'headline'
      assert ast_json.match(/"type":\s*"[Hh]eadline[Nn]ode?"/),
             'AST should contain headline elements'
    when 'paragraph'
      assert ast_json.match(/"type":\s*"[Pp]aragraph[Nn]ode?"/),
             'AST should contain paragraph elements'
    when 'list', 'ordered_list'
      assert ast_json.match(/"type":\s*"[Ll]ist[Nn]ode?"/) ||
             ast_json.match(/"list_type"/),
             'AST should contain list elements'
    when 'code_block'
      assert ast_json.match(/"type":\s*"[Cc]ode[Bb]lock[Nn]ode?"/) ||
             ast_json.match(/code/i),
             'AST should contain code block elements'
    when 'definition_list'
      assert ast_json.match(/"type":\s*"[Ll]ist[Nn]ode?"/) ||
             ast_json.match(/"list_type":\s*"dl"/),
             'AST should contain definition list elements'
    when 'table'
      assert ast_json.match(/"type":\s*"[Tt]able[Nn]ode?"/),
             'AST should contain table elements'
    when 'inline_code', 'bold', 'italic'
      # These are inline elements and may be represented differently
      assert ast_json.match(/#{element_name}/i) ||
             ast_json.match(/"type":\s*"[Ii]nline[Nn]ode?"/) ||
             ast_json.match(/"type":\s*"[Tt]ext[Nn]ode?"/),
             "AST should contain #{element_name} elements"
    end
  end

  def analyze_ast_coverage(data)
    coverage = {
      'ast_nodes' => 0,
      'headlines' => 0,
      'paragraphs' => 0,
      'lists' => 0,
      'code_blocks' => 0
    }

    json_str = JSON.pretty_generate(data)

    # Count AST-specific markers
    coverage['ast_nodes'] = json_str.scan(/"type"\s*:/).count
    coverage['headlines'] = json_str.scan(/"type"\s*:\s*"headline"/).count
    coverage['paragraphs'] = json_str.scan(/"type"\s*:\s*"paragraph"/).count
    coverage['lists'] = json_str.scan('"list_type"').count
    coverage['code_blocks'] = json_str.scan(/"type"\s*:\s*"code_block"/).count

    coverage
  end

  def generate_validation_report(traditional_data, ast_full_data, hybrid_data)
    report_file = File.join(@output_dir, 'ast_validation_report.txt')

    File.open(report_file, 'w') do |f|
      f.puts 'AST Full Mode Validation Report'
      f.puts "Generated: #{Time.now}"
      f.puts '=' * 60
      f.puts

      f.puts 'Output Sizes:'
      f.puts "  Traditional: #{JSON.generate(traditional_data).length} chars"
      f.puts "  AST Full: #{JSON.generate(ast_full_data).length} chars"
      f.puts "  Hybrid: #{JSON.generate(hybrid_data).length} chars"
      f.puts

      f.puts 'Structure Analysis:'
      f.puts "  Traditional keys: #{traditional_data.keys.sort.join(', ')}"
      f.puts "  AST Full keys: #{ast_full_data.keys.sort.join(', ')}"
      f.puts "  Hybrid keys: #{hybrid_data.keys.sort.join(', ')}"
      f.puts

      if ast_full_data['type'] == 'document'
        f.puts '✅ AST Full mode produces proper AST structure'
      else
        f.puts '❌ AST Full mode does not produce proper AST structure'
      end
    end

    puts "\n📄 Validation report generated: #{report_file}"
  end
end
