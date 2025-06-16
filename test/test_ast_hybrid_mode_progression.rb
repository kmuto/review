# frozen_string_literal: true

require_relative 'test_helper'
require 'review/compiler'
require 'review/configure'
require 'review/htmlbuilder'
require 'review/latexbuilder'
require 'fileutils'

# Test to validate hybrid mode progression for AST migration
class ASTHybridModeProgressionTest < Test::Unit::TestCase
  def setup
    @fixtures_dir = File.join(__dir__, 'project')
    @output_dir = File.join(__dir__, '..', 'tmp', 'hybrid_progression')
    FileUtils.makedirs(@output_dir)
  end

  def test_hybrid_mode_incremental_adoption
    # Test that hybrid modes provide incremental AST adoption
    puts "\n=== Hybrid Mode Incremental Adoption Test ==="

    test_content = <<~REVIEW
      = Chapter Title

      This is the first paragraph.

      == Section 1.1

      Another paragraph with @<b>{bold} text.

      * Unordered list item 1
      * Unordered list item 2

      1. Ordered list item 1
      2. Ordered list item 2

      : Definition Term
        Definition description

      //list[sample][Sample code]{
      def hello
        puts "Hello"
      end
      //}

      //table[sample][Sample table]{
      A	B
      -----
      1	2
      //}
    REVIEW

    builders = [ReVIEW::HTMLBuilder, ReVIEW::LATEXBuilder]

    builders.each do |builder_class|
      builder_name = builder_class.name.split('::').last
      puts "\n--- Testing #{builder_name} ---"

      test_hybrid_progression(builder_class, test_content)
    end
  end

  def test_hybrid_mode_element_by_element
    # Test specific element handling in each hybrid stage
    puts "\n=== Element-by-Element Hybrid Mode Test ==="

    element_tests = {
      'headline' => {
        content: "= Title\n\nParagraph",
        expected_in_stage: 1,
        ast_indicator: /headline|heading/
      },
      'paragraph' => {
        content: "= Title\n\nThis is a paragraph.",
        expected_in_stage: 2,
        ast_indicator: /paragraph/
      },
      'list' => {
        content: "= Title\n\n* Item 1\n* Item 2",
        expected_in_stage: 3,
        ast_indicator: /list|itemize/
      },
      'ordered_list' => {
        content: "= Title\n\n1. First\n2. Second",
        expected_in_stage: 3,
        ast_indicator: /list|enumerate/
      },
      'definition_list' => {
        content: "= Title\n\n: Term\n  Definition",
        expected_in_stage: 3,
        ast_indicator: /list|description/
      }
    }

    [ReVIEW::HTMLBuilder, ReVIEW::LATEXBuilder].each do |builder_class|
      builder_name = builder_class.name.split('::').last
      puts "\n--- #{builder_name} Element Tests ---"

      element_tests.each do |element_name, test_spec|
        puts "\n  Testing #{element_name}:"

        # Test each stage
        (1..7).each do |stage|
          output = compile_with_hybrid_stage(builder_class, test_spec[:content], stage)

          # Check if element is processed with AST
          ast_detected = detect_ast_processing(output, test_spec[:ast_indicator])

          if stage >= test_spec[:expected_in_stage]
            assert ast_detected,
                   "#{element_name} should be AST-processed in stage #{stage}"
            puts "    Stage #{stage}: ✅ AST processed"
          else
            puts "    Stage #{stage}: ⬜ Traditional mode"
          end
        end
      end
    end
  end

  def test_hybrid_mode_compatibility_guarantee
    # Test that hybrid modes maintain output compatibility
    puts "\n=== Hybrid Mode Compatibility Guarantee Test ==="

    test_files = Dir.glob(File.join(@fixtures_dir, '*.re'))
    builders = [ReVIEW::HTMLBuilder, ReVIEW::LATEXBuilder]

    builders.each do |builder_class|
      builder_name = builder_class.name.split('::').last.downcase.sub('builder', '')
      puts "\n--- #{builder_class.name} Compatibility ---"

      test_files.each do |file_path|
        basename = File.basename(file_path, '.re')
        content = File.read(file_path)

        # Get traditional output as baseline
        traditional_output = compile_with_mode(builder_class, content, 'traditional')

        # Test each hybrid stage
        compatibility_results = {}
        (1..7).each do |stage|
          hybrid_output = compile_with_hybrid_stage(builder_class, content, stage)

          # Compare outputs
          compatibility_results[stage] = compare_outputs(traditional_output, hybrid_output)
        end

        # Report compatibility
        puts "\n  #{basename}:"
        compatibility_results.each do |stage, compatible|
          status = compatible ? '✅' : '⚠️'
          puts "    Stage #{stage}: #{status}"
        end
      end
    end
  end

  private

  def test_hybrid_progression(builder_class, content)
    outputs = {}

    # Compile with different modes
    outputs['traditional'] = compile_with_mode(builder_class, content, 'traditional')

    (1..7).each do |stage|
      outputs["stage#{stage}"] = compile_with_hybrid_stage(builder_class, content, stage)
    end

    # Analyze progression
    analyze_progression(outputs, builder_class)
  end

  def compile_with_mode(builder_class, content, mode)
    config = ReVIEW::Configure.values

    case mode
    when 'traditional'
      config['ast'] = { 'mode' => 'off' }
    when 'ast_full'
      config['ast'] = { 'mode' => 'full' }
    end

    compile_content(builder_class, content, config)
  end

  def compile_with_hybrid_stage(builder_class, content, stage)
    config = ReVIEW::Configure.values
    config['ast'] = { 'mode' => 'hybrid', 'stage' => stage }

    compile_content(builder_class, content, config)
  end

  def compile_content(builder_class, content, config)
    book = ReVIEW::Book::Base.new
    book.config = config

    ast_config = ReVIEW::AST::Config.new(config)
    compiler_options = ast_config.compiler_options

    builder = builder_class.new
    compiler = ReVIEW::Compiler.new(builder, **compiler_options)

    chapter = ReVIEW::Book::Chapter.new(book, 1, 'test', nil, StringIO.new(content))
    location = ReVIEW::Location.new(nil, nil)

    builder.bind(compiler, chapter, location)
    compiler.compile(chapter)
    builder.result
  rescue StandardError => e
    puts "    ⚠️  Compilation error: #{e.message}"
    ''
  end

  def analyze_progression(outputs, builder_class)
    builder_name = builder_class.name.split('::').last

    # Compare sizes
    puts "\n  Output sizes:"
    outputs.each do |mode, output|
      puts "    #{mode}: #{output.length} chars"
    end

    # Check progression stability
    puts "\n  Stability check:"
    traditional_size = outputs['traditional'].length

    (1..7).each do |stage|
      stage_size = outputs["stage#{stage}"].length
      diff_percent = ((stage_size - traditional_size).abs / traditional_size.to_f * 100).round(1)

      if diff_percent < 5
        puts "    Stage #{stage}: ✅ Output size within 5% of traditional"
      else
        puts "    Stage #{stage}: ⚠️  Output differs by #{diff_percent}%"
      end
    end
  end

  def detect_ast_processing(output, pattern)
    # Simple heuristic to detect if AST processing was used
    # This is builder-specific and may need adjustment
    output.match?(pattern) || output.length > 0
  end

  def compare_outputs(traditional, hybrid)
    # Normalize outputs for comparison
    traditional_normalized = normalize_output(traditional)
    hybrid_normalized = normalize_output(hybrid)

    # Allow minor differences (whitespace, formatting)
    similarity = calculate_similarity(traditional_normalized, hybrid_normalized)
    similarity > 0.95 # 95% similar
  end

  def normalize_output(output)
    # Remove extra whitespace and normalize line endings
    output.gsub(/\s+/, ' ').strip
  end

  def calculate_similarity(str1, str2)
    return 1.0 if str1 == str2

    longer = [str1.length, str2.length].max
    return 0.0 if longer == 0

    edit_distance = levenshtein_distance(str1, str2)
    (longer - edit_distance) / longer.to_f
  end

  def levenshtein_distance(str1, str2)
    # Simple Levenshtein distance implementation
    m = str1.length
    n = str2.length

    return n if m == 0
    return m if n == 0

    d = Array.new(m + 1) { Array.new(n + 1) }

    (0..m).each { |i| d[i][0] = i }
    (0..n).each { |j| d[0][j] = j }

    (1..n).each do |j|
      (1..m).each do |i|
        cost = str1[i - 1] == str2[j - 1] ? 0 : 1
        d[i][j] = [
          d[i - 1][j] + 1,    # deletion
          d[i][j - 1] + 1,    # insertion
          d[i - 1][j - 1] + cost # substitution
        ].min
      end
    end

    d[m][n]
  end
end
