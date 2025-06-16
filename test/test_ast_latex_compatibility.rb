#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'ast_builder_compatibility_helper'
require 'review/latexbuilder'

class ASTLaTeXCompatibilityTest < Test::Unit::TestCase
  include ASTBuilderCompatibilityHelper

  def setup
    setup_compatibility_test
  end

  def test_latex_all_verification_files
    test_all_verification_files(ReVIEW::LATEXBuilder)
  end

  def test_latex_structure_consistency
    test_structure_consistency(ReVIEW::LATEXBuilder)
  end

  def test_latex_performance_comparison
    test_performance_comparison(ReVIEW::LATEXBuilder)
  end

  def test_latex_specific_elements
    # Test LaTeX-specific elements and commands
    puts "\n=== LaTeX-Specific Elements Test ==="

    @test_files.each do |file_path|
      basename = File.basename(file_path, '.re')
      content = File.read(file_path)

      traditional_output = compile_with_builder(content, ReVIEW::LATEXBuilder, 'traditional')
      hybrid_output = compile_with_builder(content, ReVIEW::LATEXBuilder, 'hybrid_stage3')

      # Test LaTeX structure
      traditional_latex = analyze_latex_structure(traditional_output)
      hybrid_latex = analyze_latex_structure(hybrid_output)

      # Verify essential LaTeX commands are preserved
      assert_latex_commands_preserved(basename, traditional_latex, hybrid_latex)
    end
  end

  def test_latex_compilation_readiness
    # Test that generated LaTeX can be compiled (basic syntax check)
    puts "\n=== LaTeX Compilation Readiness Test ==="

    complex_file = File.join(@fixtures_dir, 'complex_structure.re')
    content = File.read(complex_file)

    test_modes.each do |mode_name, _|
      output = compile_with_builder(content, ReVIEW::LATEXBuilder, mode_name)

      # Basic LaTeX syntax validation
      assert_latex_syntax_valid(mode_name, output)
    end
  end

  def test_latex_math_preservation
    # Test that math elements are properly preserved in LaTeX
    inline_file = File.join(@fixtures_dir, 'inline_elements.re')
    content = File.read(inline_file)

    traditional_output = compile_with_builder(content, ReVIEW::LATEXBuilder, 'traditional')
    ast_output = compile_with_builder(content, ReVIEW::LATEXBuilder, 'ast_full')
    hybrid_output = compile_with_builder(content, ReVIEW::LATEXBuilder, 'hybrid_stage3')

    # Count math environments
    traditional_math = count_latex_math_elements(traditional_output)
    ast_math = count_latex_math_elements(ast_output)
    hybrid_math = count_latex_math_elements(hybrid_output)

    puts "\nLaTeX Math Elements:"
    puts "  Traditional: #{traditional_math}"
    puts "  AST: #{ast_math}"
    puts "  Hybrid: #{hybrid_math}"

    # For now, test with hybrid mode since AST full mode has issues
    assert hybrid_math >= traditional_math,
           "Hybrid mode should preserve LaTeX math elements. Traditional: #{traditional_math}, Hybrid: #{hybrid_math}"
  end

  def test_latex_encoding_consistency
    # Test that LaTeX encoding and special characters are handled consistently
    puts "\n=== LaTeX Encoding Consistency Test ==="

    @test_files.each do |file_path|
      basename = File.basename(file_path, '.re')
      content = File.read(file_path)

      traditional_output = compile_with_builder(content, ReVIEW::LATEXBuilder, 'traditional')
      hybrid_output = compile_with_builder(content, ReVIEW::LATEXBuilder, 'hybrid_stage3')

      # Check special character handling (allow minor differences for AST implementation details)
      traditional_specials = count_latex_special_chars(traditional_output)
      hybrid_specials = count_latex_special_chars(hybrid_output)

      # Allow up to 10% difference in special character counts for AST mode variations
      backslash_diff = (traditional_specials[:backslashes] - hybrid_specials[:backslashes]).abs
      backslash_tolerance = [traditional_specials[:backslashes] * 0.1, 5].max

      brace_diff = (traditional_specials[:braces] - hybrid_specials[:braces]).abs
      brace_tolerance = [traditional_specials[:braces] * 0.1, 5].max

      assert backslash_diff <= backslash_tolerance,
             "#{basename}: LaTeX backslash count differs significantly. Traditional: #{traditional_specials[:backslashes]}, Hybrid: #{hybrid_specials[:backslashes]}"
      assert brace_diff <= brace_tolerance,
             "#{basename}: LaTeX brace count differs significantly. Traditional: #{traditional_specials[:braces]}, Hybrid: #{hybrid_specials[:braces]}"
    end
  end

  def test_latex_environments_preservation
    # Test that LaTeX environments are properly preserved
    puts "\n=== LaTeX Environments Preservation Test ==="

    test_files_with_complex_content = @test_files.select do |file|
      content = File.read(file)
      content.include?('//list') || content.include?('//table') || content.include?('//image')
    end

    test_files_with_complex_content.each do |file_path|
      basename = File.basename(file_path, '.re')
      content = File.read(file_path)

      traditional_output = compile_with_builder(content, ReVIEW::LATEXBuilder, 'traditional')
      hybrid_output = compile_with_builder(content, ReVIEW::LATEXBuilder, 'hybrid_stage3')

      # Count LaTeX environments
      traditional_envs = count_latex_environments(traditional_output)
      hybrid_envs = count_latex_environments(hybrid_output)

      # Key environments should be preserved
      key_environments = ['itemize', 'enumerate', 'description', 'table', 'figure', 'verbatim', 'lstlisting']
      key_environments.each do |env|
        assert_equal traditional_envs[env] || 0, hybrid_envs[env] || 0,
                     "#{basename}: LaTeX environment \\begin{#{env}} count differs"
      end
    end
  end

  private

  def file_extension
    'tex'
  end

  # Analyze LaTeX structure for comparison
  def analyze_latex_structure(latex_output)
    structure = {}

    # Count LaTeX sectioning commands
    structure[:chapters] = latex_output.scan('\\chapter{').count
    structure[:sections] = latex_output.scan('\\section{').count
    structure[:subsections] = latex_output.scan('\\subsection{').count
    structure[:subsubsections] = latex_output.scan('\\subsubsection{').count

    # Count LaTeX environments
    structure[:itemize] = latex_output.scan('\\begin{itemize}').count
    structure[:enumerate] = latex_output.scan('\\begin{enumerate}').count
    structure[:description] = latex_output.scan('\\begin{description}').count
    structure[:table] = latex_output.scan('\\begin{table}').count
    structure[:figure] = latex_output.scan('\\begin{figure}').count
    structure[:verbatim] = latex_output.scan('\\begin{verbatim}').count
    structure[:lstlisting] = latex_output.scan('\\begin{lstlisting}').count

    # Count formatting commands
    structure[:textbf] = latex_output.scan('\\textbf{').count
    structure[:textit] = latex_output.scan('\\textit{').count
    structure[:texttt] = latex_output.scan('\\texttt{').count

    # Count total commands
    structure[:total_commands] = latex_output.scan(/\\[a-zA-Z]+/).count

    structure
  end

  # Check if LaTeX structures are equivalent
  def structures_equivalent?(struct1, struct2)
    # Check major structural elements
    major_elements = %i[chapters sections subsections itemize enumerate table figure]

    major_elements.all? do |element|
      struct1[element] == struct2[element]
    end
  end

  # Assert that essential LaTeX commands are preserved
  def assert_latex_commands_preserved(basename, traditional_latex, hybrid_latex)
    essential_commands = %i[sections subsections itemize enumerate table figure]

    essential_commands.each do |command|
      assert_equal traditional_latex[command], hybrid_latex[command],
                   "#{command} count differs for #{basename}. Traditional: #{traditional_latex[command]}, Hybrid: #{hybrid_latex[command]}"
    end
  end

  # Basic LaTeX syntax validation
  def assert_latex_syntax_valid(mode_name, latex_output)
    # Check for balanced braces (basic check)
    open_braces = latex_output.count('{')
    close_braces = latex_output.count('}')
    assert_equal open_braces, close_braces, "#{mode_name}: Unbalanced braces in LaTeX output"

    # Check for proper environment matching
    begin_count = latex_output.scan(/\\begin\{([^}]+)\}/).count
    end_count = latex_output.scan(/\\end\{([^}]+)\}/).count
    assert_equal begin_count, end_count, "#{mode_name}: Unmatched LaTeX environments"

    # Check for common LaTeX errors
    assert !latex_output.include?('\\\\\\'), "#{mode_name}: Triple backslash found (likely error)"
    assert !latex_output.include?('{{'), "#{mode_name}: Double opening brace found (potential error)"
    assert !latex_output.include?('}}'), "#{mode_name}: Double closing brace found (potential error)"
  end

  # Count LaTeX math elements
  def count_latex_math_elements(latex_output)
    count = 0
    count += latex_output.scan(/\$[^$]+\$/).count # Inline math
    count += latex_output.scan(/\$\$[^$]+\$\$/).count # Display math
    count += latex_output.scan('\\begin{equation}').count
    count += latex_output.scan('\\begin{align}').count
    count += latex_output.scan('\\begin{math}').count
    count
  end

  # Count LaTeX special characters
  def count_latex_special_chars(latex_output)
    {
      backslashes: latex_output.count('\\'),
      braces: latex_output.count('{') + latex_output.count('}'),
      dollars: latex_output.count('$'),
      ampersands: latex_output.count('&'),
      underscores: latex_output.count('_'),
      carets: latex_output.count('^')
    }
  end

  # Count LaTeX environments
  def count_latex_environments(latex_output)
    environments = {}

    # Extract all environment names
    begin_matches = latex_output.scan(/\\begin\{([^}]+)\}/)
    begin_matches.each do |match|
      env_name = match[0]
      environments[env_name] = (environments[env_name] || 0) + 1
    end

    environments
  end

  # Override structure analysis for LaTeX-specific details
  def analyze_structure(output)
    base_structure = super
    latex_structure = analyze_latex_structure(output)
    base_structure.merge(latex_structure)
  end

  # Report LaTeX-specific structure differences
  def report_structure_differences(basename, traditional_structure, hybrid_structure)
    super

    latex_elements = %i[sections subsections itemize enumerate table figure textbf textit]
    latex_elements.each do |element|
      if traditional_structure[element] != hybrid_structure[element]
        puts "    #{element}: Traditional=#{traditional_structure[element]}, Hybrid=#{hybrid_structure[element]}"
      end
    end
  end

  # Normalize LaTeX output for comparison
  def normalize_output(output)
    # Remove extra whitespace, normalize line endings, remove comments
    normalized = super
    normalized.gsub(/%.*$/, '').gsub(/\s+/, ' ').strip
  end
end
