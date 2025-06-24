# frozen_string_literal: true

require 'fileutils'
require 'parallel'
require_relative 'comparator'
require_relative 'reporter'
require_relative '../review/html_converter'
require_relative '../review/latex_converter'

module ReVIEW
  module Compat
    class Runner
      def initialize(options = {})
        @format = options[:format] || 'all' # 'html', 'latex', 'all'
        @fixtures_dir = options[:fixtures_dir] || 'fixtures/compat'
        @output_dir = options[:output_dir] || 'reports/compat'
        @verbose = options[:verbose] || false
        @parallel = options[:parallel] != false # デフォルトでtrue
        @pattern = options[:pattern]
        @show_diff = options[:show_diff] || false
        @results = []
        @reporter = Reporter.new(@output_dir)
      end

      def run
        puts 'Starting compatibility check...' if @verbose

        prepare_directories
        test_files = collect_test_files

        if test_files.empty?
          puts "No test files found in #{@fixtures_dir}"
          return 1
        end

        puts "Found #{test_files.length} test files" if @verbose

        if @parallel && test_files.length > 1
          run_parallel_checks(test_files)
        else
          run_sequential_checks(test_files)
        end

        generate_reports
        print_summary
        exit_code
      end

      private

      def prepare_directories
        FileUtils.mkdir_p(@output_dir)
        FileUtils.mkdir_p(File.join(@output_dir, 'output', 'html'))
        FileUtils.mkdir_p(File.join(@output_dir, 'output', 'latex'))
      end

      def collect_test_files
        pattern = @pattern || '**/*.re'
        search_pattern = File.join(@fixtures_dir, pattern)
        Dir.glob(search_pattern).sort
      end

      def run_parallel_checks(test_files)
        puts 'Running checks in parallel...' if @verbose

        results = Parallel.map(test_files, in_processes: 4) do |file|
          check_single_file(file)
        end

        # 結果をフラット化してマージ
        @results = results.flatten.compact
      end

      def run_sequential_checks(test_files)
        puts 'Running checks sequentially...' if @verbose

        test_files.each do |file|
          results = check_single_file(file)
          @results.concat(results)
        end
      end

      def check_single_file(re_file)
        puts "Checking: #{re_file}" if @verbose
        results = []

        begin
          if @format == 'html' || @format == 'all'
            result = compare_format(re_file, 'html')
            results << result if result
          end

          if @format == 'latex' || @format == 'all'
            result = compare_format(re_file, 'latex')
            results << result if result
          end
        rescue StandardError => e
          puts "Error processing #{re_file}: #{e.message}" if @verbose
          puts e.backtrace.join("\n") if @verbose
        end

        results
      end

      def compare_format(re_file, format)
        puts "  - #{format.upcase} comparison" if @verbose

        begin
          builder_output = generate_with_builder(re_file, format)
          renderer_output = generate_with_renderer(re_file, format)

          comparator = Comparator.new(format, show_diff: @show_diff)
          comparison_result = comparator.compare(builder_output, renderer_output)

          save_outputs(re_file, format, builder_output, renderer_output)

          # レポーターに結果を追加
          @reporter.add_result(re_file, format, comparison_result)

          {
            file: re_file,
            format: format,
            status: comparison_result[:status],
            differences: comparison_result[:differences],
            comparison_result: comparison_result
          }
        rescue StandardError => e
          puts "Error comparing #{format} for #{re_file}: #{e.message}" if @verbose

          {
            file: re_file,
            format: format,
            status: :error,
            error: e.message,
            differences: []
          }
        end
      end

      def generate_with_builder(re_file, format)
        case format
        when 'html'
          converter = HTMLConverter.new
          converter.convert_with_builder(File.read(re_file))
        when 'latex'
          converter = LATEXConverter.new
          converter.convert_with_builder(File.read(re_file))
        else
          raise "Unsupported format: #{format}"
        end
      end

      def generate_with_renderer(re_file, format)
        case format
        when 'html'
          converter = HTMLConverter.new
          converter.convert_with_renderer(File.read(re_file))
        when 'latex'
          converter = LATEXConverter.new
          converter.convert_with_renderer(File.read(re_file))
        else
          raise "Unsupported format: #{format}"
        end
      end

      def save_outputs(re_file, format, builder_output, renderer_output)
        base_name = File.basename(re_file, '.re')

        # Builder出力を保存
        builder_file = File.join(@output_dir, 'output', format, "#{base_name}_builder.#{format}")
        File.write(builder_file, builder_output)

        # Renderer出力を保存
        renderer_file = File.join(@output_dir, 'output', format, "#{base_name}_renderer.#{format}")
        File.write(renderer_file, renderer_output)

        puts "    Saved outputs to #{File.dirname(builder_file)}" if @verbose
      end

      def generate_reports
        puts 'Generating reports...' if @verbose
        @reporter.generate_reports
        puts "Reports generated in #{@output_dir}" if @verbose
      end

      def print_summary
        summary = @reporter.summary

        puts "\n" + ('=' * 50)
        puts 'COMPATIBILITY CHECK SUMMARY'
        puts '=' * 50
        puts "Total checks: #{summary[:total]}"
        puts "Passed: #{summary[:passed]}"
        puts "Known differences: #{summary[:known_differences]}"
        puts "Failed: #{summary[:failed]}"
        puts "Success rate: #{summary[:success_rate]}%"
        puts '=' * 50

        if summary[:failed] > 0
          puts "\nFailed checks:"
          @results.select { |r| r[:status] == :fail }.each do |result|
            puts "  - #{result[:file]} (#{result[:format]}): #{result[:differences]&.length || 0} differences"
          end
        end

        puts "\nDetailed report: #{File.join(@output_dir, 'summary.html')}"
      end

      def exit_code
        failed_count = @results.count { |r| r[:status] == :fail || r[:status] == :error }
        failed_count > 0 ? 1 : 0
      end
    end
  end
end
