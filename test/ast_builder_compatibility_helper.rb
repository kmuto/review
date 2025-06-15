#!/usr/bin/env ruby
# frozen_string_literal: true

require 'review'
require 'review/ast/config'
require 'stringio'
require 'fileutils'

# AST Builder Compatibility Test Helper Module
#
# This module provides common functionality for testing AST compatibility
# across different builders (HTML, LaTeX, JSON, etc.)
module ASTBuilderCompatibilityHelper
  def setup_compatibility_test
    @fixtures_dir = File.join(__dir__, 'project')
    @test_files = Dir.glob(File.join(@fixtures_dir, '*.re')).reject do |f|
      File.basename(f).start_with?('test_stage') ||
        File.basename(f) == 'test-project.re' ||
        File.basename(f) == 'comprehensive_test.re'
    end.sort
    @output_dir = File.join(__dir__, '..', 'tmp', 'compatibility')
    FileUtils.mkdir_p(@output_dir)

    # Initialize I18n
    ReVIEW::I18n.setup('ja')

    @test_results = {}
    @builder_name = self.class.name.gsub(/Test$/, '').downcase.gsub(/ast|builder|compatibility/, '')
  end

  # Test modes for compatibility verification
  def test_modes
    {
      'traditional' => { 'mode' => 'off' },
      'ast_full' => { 'mode' => 'full' },
      'hybrid_stage3' => { 'mode' => 'hybrid', 'stage' => 3 },
      'hybrid_stage7' => { 'mode' => 'hybrid', 'stage' => 7 }
    }
  end

  # Compile content with specified builder and AST configuration
  def compile_with_builder(content, builder_class, mode_name, ast_config = nil)
    # Create configuration
    review_config = ReVIEW::Configure.values

    case mode_name
    when 'traditional'
      review_config['ast'] = { 'mode' => 'off' }
    when 'ast_full'
      review_config['ast'] = { 'mode' => 'full' }
    when 'hybrid_stage3'
      review_config['ast'] = { 'mode' => 'hybrid', 'stage' => 3 }
    when 'hybrid_stage7'
      review_config['ast'] = { 'mode' => 'hybrid', 'stage' => 7 }
    else
      review_config['ast'] = ast_config if ast_config
    end

    # Create compiler and builder
    ast_config_obj = ReVIEW::AST::Config.new(review_config)
    compiler_options = ast_config_obj.compiler_options

    builder = builder_class.new
    compiler = ReVIEW::Compiler.new(builder, **compiler_options)

    # Set up book and chapter
    book = ReVIEW::Book::Base.new
    book.config = review_config

    chapter = ReVIEW::Book::Chapter.new(book, 1, 'test', nil, StringIO.new(content))
    location = ReVIEW::Location.new(nil, nil)

    # Initialize chapter with empty indexes to avoid reference errors
    begin
      chapter.instance_eval do
        @list_index = {}
        @table_index = {}
        @image_index = {}
        @equation_index = {}
        @headline_index = {}
        @bib_index = {}
        @numberless_image_index = {}
        @indepimage_index = {}
        @fn_index = {}
        @endnote_index = {}
        @icon_index = {}
        @column_index = {}
      end
    rescue StandardError => e
      # Ignore initialization errors for compatibility
    end
    builder.bind(compiler, chapter, location)

    # Compile and return output
    compiler.compile(chapter)
  end

  # Test file compatibility across all modes
  def test_file_compatibility(basename, content, builder_class)
    puts "  📄 File compatibility test for #{basename}..."

    results = {}

    test_modes.each do |mode_name, _ast_config|
      begin
        output = compile_with_builder(content, builder_class, mode_name)

        # Save output for manual inspection
        output_file = File.join(@output_dir, "#{basename}_#{mode_name}_#{@builder_name}.#{file_extension}")
        File.write(output_file, output)

        results[mode_name] = {
          success: true,
          output: output,
          output_file: output_file,
          size: output.length,
          lines: output.lines.count
        }

        puts "    ✅ #{mode_name}: #{results[mode_name][:size]} chars, #{results[mode_name][:lines]} lines"
      rescue StandardError => e
        results[mode_name] = {
          success: false,
          error: e.message,
          output_file: File.join(@output_dir, "#{basename}_#{mode_name}_#{@builder_name}_ERROR.txt")
        }

        File.write(results[mode_name][:output_file], e.message + "\n" + e.backtrace.join("\n"))
        puts "    ❌ #{mode_name}: #{e.message}"
      end
    end

    @test_results[basename] = results

    # Verify all modes produced output
    results.each do |mode_name, result|
      assert result[:success], "#{mode_name} mode failed for #{basename}: #{result[:error]}"
    end

    # Check output consistency
    verify_output_consistency(basename, results)

    results
  end

  # Verify output consistency between different modes
  def verify_output_consistency(basename, results)
    successful_results = results.select { |_, r| r[:success] }
    return if successful_results.size < 2

    # Compare traditional vs hybrid stage3 (should be identical for basic elements)
    if successful_results.key?('traditional') && successful_results.key?('hybrid_stage3')
      traditional_output = successful_results['traditional'][:output]
      hybrid_output = successful_results['hybrid_stage3'][:output]

      # Normalize whitespace for comparison
      traditional_normalized = normalize_output(traditional_output)
      hybrid_normalized = normalize_output(hybrid_output)

      if traditional_normalized == hybrid_normalized
        puts "    ✅ #{basename}: Traditional and Hybrid Stage3 outputs are identical"
      else
        puts "    ⚠️  #{basename}: Output differs between Traditional and Hybrid Stage3"
        save_diff_report(basename, traditional_output, hybrid_output)
      end
    end

    # Check size consistency
    sizes = successful_results.transform_values { |r| r[:size] }
    if sizes.values.uniq.length == 1
      puts "    ✅ #{basename}: All modes produce same output size"
    else
      puts "    ⚠️  #{basename}: Output size varies: #{sizes}"
    end
  end

  # Normalize output for comparison (remove minor formatting differences)
  def normalize_output(output)
    # Remove extra whitespace, normalize line endings
    output.gsub(/\s+/, ' ').strip.gsub("\r\n", "\n")
  end

  # Save detailed diff report for manual review
  def save_diff_report(basename, traditional_output, hybrid_output)
    diff_file = File.join(@output_dir, "#{basename}_#{@builder_name}_DIFF.txt")

    File.open(diff_file, 'w') do |f|
      f.puts "=== DIFF REPORT FOR #{basename} (#{@builder_name.upcase}) ==="
      f.puts "Generated: #{Time.now}"
      f.puts '=' * 60
      f.puts
      f.puts '=== TRADITIONAL OUTPUT ==='
      f.puts traditional_output
      f.puts
      f.puts '=== HYBRID STAGE3 OUTPUT ==='
      f.puts hybrid_output
      f.puts
      f.puts '=== ANALYSIS ==='
      f.puts "Traditional size: #{traditional_output.length} chars"
      f.puts "Hybrid size: #{hybrid_output.length} chars"
      f.puts "Lines differ: #{traditional_output.lines.count != hybrid_output.lines.count}"
    end

    puts "    📄 Diff report saved: #{diff_file}"
  end

  # Test all verification files
  def test_all_verification_files(builder_class)
    @test_files.each do |file_path|
      basename = File.basename(file_path, '.re')
      puts "\n=== Testing #{basename} with #{builder_class} ==="

      content = File.read(file_path)
      test_file_compatibility(basename, content, builder_class)
    end

    generate_compatibility_report(builder_class)
  end

  # Test structure consistency across modes
  def test_structure_consistency(builder_class)
    puts "\n=== Structure Consistency Test for #{builder_class} ==="

    @test_files.each do |file_path|
      basename = File.basename(file_path, '.re')
      content = File.read(file_path)

      # Skip very small files
      next if content.strip.length < 50

      traditional_output = compile_with_builder(content, builder_class, 'traditional')
      hybrid_output = compile_with_builder(content, builder_class, 'hybrid_stage3')

      # Check for major structural differences
      traditional_structure = analyze_structure(traditional_output)
      hybrid_structure = analyze_structure(hybrid_output)

      if structures_equivalent?(traditional_structure, hybrid_structure)
        puts "  ✅ #{basename}: Structures are equivalent"
      else
        puts "  ⚠️  #{basename}: Structural differences detected"
        report_structure_differences(basename, traditional_structure, hybrid_structure)
      end
    end
  end

  # Analyze output structure (to be overridden by specific builders)
  def analyze_structure(output)
    {
      lines: output.lines.count,
      size: output.length,
      non_empty_lines: output.lines.reject(&:strip).count
    }
  end

  # Check if structures are equivalent (to be overridden by specific builders)
  def structures_equivalent?(struct1, struct2)
    struct1[:lines] == struct2[:lines] &&
      (struct1[:size] - struct2[:size]).abs < 100 # Allow minor size differences
  end

  # Report structure differences
  def report_structure_differences(_basename, traditional_structure, hybrid_structure)
    puts "    Traditional: #{traditional_structure.inspect}"
    puts "    Hybrid: #{hybrid_structure.inspect}"
  end

  # Generate comprehensive compatibility report
  def generate_compatibility_report(builder_class)
    report_file = File.join(@output_dir, "#{@builder_name}_compatibility_report.txt")

    File.open(report_file, 'w') do |f|
      f.puts "#{@builder_name.upcase} Builder AST Compatibility Report"
      f.puts "Builder: #{builder_class}"
      f.puts "Generated: #{Time.now}"
      f.puts '=' * 60
      f.puts

      success_count = 0
      total_count = 0

      @test_results.each do |basename, results|
        f.puts "File: #{basename}"
        f.puts '-' * 40

        results.each do |mode, result|
          total_count += 1
          if result[:success]
            success_count += 1
            f.puts "  #{mode.ljust(15)}: ✅ #{result[:size]} chars, #{result[:lines]} lines"
          else
            f.puts "  #{mode.ljust(15)}: ❌ #{result[:error]}"
          end
        end

        f.puts
      end

      f.puts 'Summary:'
      f.puts "  Total tests: #{total_count}"
      f.puts "  Successful: #{success_count}"
      f.puts "  Success rate: #{(success_count.to_f / total_count * 100).round(1)}%"
      f.puts "  All files passed: #{@test_results.values.all? { |r| r.values.all? { |mode_result| mode_result[:success] } }}"
    end

    puts "\n📄 Compatibility report generated: #{report_file}"
  end

  # File extension for output files (to be overridden by specific builders)
  def file_extension
    'txt'
  end

  # Performance comparison test
  def test_performance_comparison(builder_class)
    puts "\n=== Performance Comparison Test for #{builder_class} ==="

    # Use complex structure file for performance testing
    large_test_file = File.join(@fixtures_dir, 'complex_structure.re')
    content = File.read(large_test_file)

    # Repeat content to make it larger
    large_content = content * 3

    times = {}

    test_modes.keys.each do |mode|
      start_time = Time.now
      5.times { compile_with_builder(large_content, builder_class, mode) }
      end_time = Time.now

      times[mode] = ((end_time - start_time) * 1000 / 5).round(2) # Average time in ms
    end

    puts "\n#{@builder_name.upcase} Generation Performance (average per compile):"
    times.each { |mode, time| puts "  #{mode}: #{time}ms" }

    # Verify no mode is dramatically slower (arbitrary 5x threshold)
    baseline = times['traditional']
    times.each do |mode, time|
      ratio = time / baseline
      assert ratio < 5.0, "#{mode} mode is too slow compared to traditional (#{ratio.round(2)}x slower) for #{builder_class}"
    end

    times
  end
end
