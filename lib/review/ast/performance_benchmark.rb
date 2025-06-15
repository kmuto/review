# frozen_string_literal: true

require 'benchmark'
require 'json'

module ReVIEW
  module AST
    # Comprehensive performance benchmarking for AST vs Traditional processing
    class PerformanceBenchmark
      def initialize
        @results = {}
        @samples = create_benchmark_samples
        @iterations = 10 # Number of iterations for stable measurements
        FileUtils.mkdir_p('./tmp')
      end

      def run_comprehensive_benchmark
        puts '=== Re:VIEW AST Performance Benchmark ==='
        puts 'Running comprehensive performance analysis...'
        puts "Iterations per test: #{@iterations}"
        puts '=' * 70

        @samples.each do |sample_name, content|
          puts "\n--- Testing Sample: #{sample_name} ---"
          puts "Content size: #{content.length} characters"

          benchmark_sample(sample_name, content)
        end

        generate_performance_report
        analyze_performance_patterns
        check_performance_criteria
      end

      private

      def create_benchmark_samples
        {
          'simple' => create_simple_sample,
          'medium' => create_medium_sample,
          'complex' => create_complex_sample,
          'large' => create_large_sample
        }
      end

      def create_simple_sample
        <<~CONTENT
          = Simple Chapter
          
          This is a simple paragraph with @<b>{bold} text.
          
           * List item 1
           * List item 2
          
          //table[simple][Simple Table]{
          A	B
          ----
          1	2
          //}
        CONTENT
      end

      def create_medium_sample
        <<~CONTENT
          = Medium Complexity Chapter
          
          This is a paragraph with various @<b>{formatting} and @<i>{italic} text.
          
          == Section 1
          
          Multiple paragraphs with different formatting options.
          
          === Subsection
          
          Unordered list with formatting:
          
           * First item with @<code>{code}
           * Second item with @<b>{bold formatting}
           * Third item
             * Nested item 1
             * Nested item 2
          
          Ordered list:
          
           1. Step one
           2. Step two with @<i>{emphasis}
           3. Step three
          
          Definition list:
          
          : Term A
            Definition with @<b>{formatting}
          : Term B
            Another definition
          
          //table[medium][Medium Table]{
          Header 1	Header 2	Header 3
          ----
          Cell 1	Cell 2	Cell 3
          Data A	Data B	Data C
          //}
          
          //list[code1][Sample Code]{
          def hello_world
            puts "Hello, World!"
            return true
          end
          //}
          
          //image[sample][Sample Image]
        CONTENT
      end

      def create_complex_sample
        <<~CONTENT
          = Complex Chapter with Many Elements
          
          This chapter contains many different Re:VIEW elements for comprehensive testing.
          
          == Introduction Section
          
          Multiple paragraphs with extensive @<b>{bold}, @<i>{italic}, @<code>{inline code},
          and @<tt>{teletype} formatting to test inline processing performance.
          
          === Lists Section
          
          Complex nested unordered list:
          
           * Top level item 1
             * Nested item 1.1 with @<b>{formatting}
             * Nested item 1.2
               * Deep nested item 1.2.1
               * Deep nested item 1.2.2
           * Top level item 2
             * Nested item 2.1
           * Top level item 3
          
          Numbered list with various content:
          
           1. First step with @<code>{code example}
           2. Second step with complex text and @<i>{emphasis}
           3. Third step
           4. Fourth step with @<href>{http://example.com, link}
           5. Fifth step
          
          Definition list with formatting:
          
          : Technical Term A
            Complex definition with @<b>{bold text} and @<code>{code examples}
          : Technical Term B
            Another definition with @<i>{italic formatting}
          : Technical Term C
            Definition with multiple lines and various formatting options
          
          === Tables Section
          
          //table[complex1][Complex Table 1]{
          Column A	Column B	Column C	Column D
          ----
          Data 1A	Data 1B	Data 1C	Data 1D
          Data 2A	Data 2B	Data 2C	Data 2D
          Data 3A	Data 3B	Data 3C	Data 3D
          //}
          
          //table[complex2][Another Table]{
          Name	Age	City	Country
          ----
          Alice	25	Tokyo	Japan
          Bob	30	London	UK
          Charlie	35	New York	USA
          //}
          
          === Code Blocks Section
          
          //list[ruby1][Ruby Example]{
          class PerformanceTest
            def initialize(name)
              @name = name
              @results = []
            end
            
            def run_test
              start_time = Time.now
              yield if block_given?
              end_time = Time.now
              @results << (end_time - start_time)
            end
            
            def average_time
              @results.sum / @results.size.to_f
            end
          end
          //}
          
          //listnum[python1][Python Example with Numbers]{
          def fibonacci(n):
              if n <= 1:
                  return n
              else:
                  return fibonacci(n-1) + fibonacci(n-2)
          
          # Calculate first 10 Fibonacci numbers
          for i in range(10):
              print(f"F({i}) = {fibonacci(i)}")
          //}
          
          //emlist[simple][Simple Code Block]{
          echo "Hello, World!"
          ls -la
          pwd
          //}
          
          //cmd{
          git status
          git add .
          git commit -m "Update performance tests"
          git push origin main
          //}
          
          === Images Section
          
          //image[figure1][Main Figure]{
          This is the main figure caption
          //}
          
          //indepimage[diagram1][Independent Diagram]
          
          //numberlessimage[photo1][Unnumbered Photo]
        CONTENT
      end

      def create_large_sample
        # Generate a large sample by repeating complex content
        base_content = create_complex_sample
        large_content = ''

        # Create 5 chapters worth of content
        (1..5).each do |i|
          chapter_content = base_content.gsub('= Complex Chapter', "= Chapter #{i}")
          chapter_content = chapter_content.gsub(/\[(\w+)\]/, "[\\1_ch#{i}]")
          large_content += chapter_content + "\n\n"
        end

        large_content
      end

      def benchmark_sample(sample_name, content)
        modes = {
          'traditional' => { mode: 'off' },
          'stage1' => { mode: 'hybrid', stage: 1 },
          'stage3' => { mode: 'hybrid', stage: 3 },
          'stage7' => { mode: 'hybrid', stage: 7 },
          'full_ast' => { mode: 'full' }
        }

        sample_results = {}

        modes.each do |mode_name, config|
          puts "  Testing #{mode_name}..."

          times = []
          memory_usage = []

          @iterations.times do |_i|
            # Force garbage collection before each test
            GC.start

            memory_before = current_memory_usage
            time = Benchmark.realtime do
              compile_with_config(content, config)
            end
            memory_after = current_memory_usage

            times << (time * 1000).round(3) # Convert to milliseconds
            memory_usage << (memory_after - memory_before)
          end

          # Calculate statistics
          avg_time = times.sum / times.size.to_f
          min_time = times.min
          max_time = times.max
          std_dev = calculate_std_deviation(times, avg_time)

          avg_memory = memory_usage.sum / memory_usage.size.to_f

          sample_results[mode_name] = {
            avg_time: avg_time.round(3),
            min_time: min_time,
            max_time: max_time,
            std_dev: std_dev.round(3),
            times: times,
            avg_memory: avg_memory.round(1),
            memory_usage: memory_usage
          }

          puts "    Average: #{avg_time.round(2)}ms (±#{std_dev.round(2)}ms)"
        end

        @results[sample_name] = sample_results
        analyze_sample_performance(sample_name, sample_results)
      end

      def compile_with_config(content, config)
        builder = ReVIEW::HTMLBuilder.new

        review_config = ReVIEW::Configure.values
        review_config['ast'] = config

        ast_config = ReVIEW::AST::Config.new(review_config)
        compiler_options = ast_config.compiler_options

        compiler = ReVIEW::Compiler.new(builder, **compiler_options)

        book = ReVIEW::Book::Base.new
        book.config = review_config

        chapter = ReVIEW::Book::Chapter.new(book, 1, 'test', nil, StringIO.new(content))
        location = ReVIEW::Location.new(nil, nil)
        builder.bind(compiler, chapter, location)

        compiler.compile(chapter)
      end

      def current_memory_usage
        # Simple memory usage approximation
        GC.stat[:total_allocated_objects]
      end

      def calculate_std_deviation(values, mean)
        variance = values.sum { |v| (v - mean)**2 } / values.size.to_f
        Math.sqrt(variance)
      end

      def analyze_sample_performance(sample_name, results)
        traditional_time = results['traditional'][:avg_time]

        puts "\n  Performance Analysis for #{sample_name}:"
        results.each do |mode, data|
          next if mode == 'traditional'

          overhead = ((data[:avg_time] - traditional_time) / traditional_time * 100).round(1)
          status = overhead <= 10 ? '✅' : '⚠️'

          puts "    #{mode}: #{overhead >= 0 ? '+' : ''}#{overhead}% overhead #{status}"
        end
      end

      def generate_performance_report
        puts "\n" + ('=' * 70)
        puts 'COMPREHENSIVE PERFORMANCE REPORT'
        puts '=' * 70

        # Summary table
        puts "\nPerformance Summary (Average Times in ms):"
        puts 'Sample'.ljust(10) + 'Traditional'.ljust(12) + 'Stage1'.ljust(10) + 'Stage3'.ljust(10) + 'Stage7'.ljust(10) + 'Full AST'.ljust(10)
        puts '-' * 62

        @results.each do |sample, modes|
          line = sample.ljust(10)
          ['traditional', 'stage1', 'stage3', 'stage7', 'full_ast'].each do |mode|
            time = modes[mode][:avg_time]
            line += time.round(2).to_s.ljust(mode == 'traditional' ? 12 : 10)
          end
          puts line
        end

        # Overhead analysis
        puts "\nOverhead Analysis (% vs Traditional):"
        puts 'Sample'.ljust(10) + 'Stage1'.ljust(10) + 'Stage3'.ljust(10) + 'Stage7'.ljust(10) + 'Full AST'.ljust(10)
        puts '-' * 50

        @results.each do |sample, modes|
          traditional = modes['traditional'][:avg_time]
          line = sample.ljust(10)

          ['stage1', 'stage3', 'stage7', 'full_ast'].each do |mode|
            overhead = ((modes[mode][:avg_time] - traditional) / traditional * 100).round(1)
            color = overhead <= 10 ? '' : ' ⚠️'
            line += "#{overhead >= 0 ? '+' : ''}#{overhead}%#{color}".ljust(10)
          end
          puts line
        end

        # Save detailed results
        save_benchmark_results
      end

      def analyze_performance_patterns
        puts "\n" + ('=' * 70)
        puts 'PERFORMANCE PATTERN ANALYSIS'
        puts '=' * 70

        # Analyze scaling with content size
        puts "\nScaling Analysis:"
        content_sizes = @results.to_h { |sample, _| [sample, @samples[sample].length] }

        traditional_scaling = []
        ast_scaling = []

        @results.each do |sample, modes|
          size = content_sizes[sample]
          trad_time = modes['traditional'][:avg_time]
          ast_time = modes['stage7'][:avg_time]

          traditional_scaling << [size, trad_time]
          ast_scaling << [size, ast_time]

          efficiency_trad = (trad_time / size * 1000).round(3)
          efficiency_ast = (ast_time / size * 1000).round(3)

          puts "#{sample.ljust(8)}: #{size.to_s.rjust(6)} chars, Traditional: #{efficiency_trad}ms/Kchar, AST: #{efficiency_ast}ms/Kchar"
        end

        # Memory usage analysis
        puts "\nMemory Usage Analysis:"
        @results.each do |sample, modes|
          puts "#{sample.capitalize} sample:"
          modes.each do |mode, data|
            puts "  #{mode.ljust(12)}: #{data[:avg_memory].round(1)} objects"
          end
        end
      end

      def check_performance_criteria
        puts "\n" + ('=' * 70)
        puts 'PERFORMANCE CRITERIA CHECK'
        puts '=' * 70

        criteria_passed = true

        @results.each do |sample, modes|
          puts "\n#{sample.capitalize} Sample:"
          traditional_time = modes['traditional'][:avg_time]

          modes.each do |mode, data|
            next if mode == 'traditional'

            overhead = ((data[:avg_time] - traditional_time) / traditional_time * 100).round(1)

            if overhead <= 10
              puts "  ✅ #{mode}: #{overhead >= 0 ? '+' : ''}#{overhead}% (within ±10% criteria)"
            else
              puts "  ❌ #{mode}: #{overhead >= 0 ? '+' : ''}#{overhead}% (exceeds ±10% criteria)"
              criteria_passed = false
            end
          end
        end

        puts "\n" + ('=' * 70)
        if criteria_passed
          puts '🎉 ALL PERFORMANCE CRITERIA MET! (±10% overhead limit)'
        else
          puts '⚠️  Some modes exceed ±10% performance criteria'
          puts 'Consider optimization for modes with high overhead'
        end
        puts '=' * 70
      end

      def save_benchmark_results
        detailed_results = {
          timestamp: Time.now.iso8601,
          ruby_version: RUBY_VERSION,
          iterations: @iterations,
          samples: @results.transform_values do |modes|
            modes.transform_values do |data|
              data.slice(:avg_time, :min_time, :max_time, :std_dev, :avg_memory)
            end
          end
        }

        File.write('./tmp/performance_benchmark.json', JSON.pretty_generate(detailed_results))
        puts "\nDetailed results saved to: ./tmp/performance_benchmark.json"
      end
    end
  end
end
