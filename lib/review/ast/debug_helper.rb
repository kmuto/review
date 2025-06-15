# frozen_string_literal: true

require 'json'
require 'tempfile'

module ReVIEW
  module AST
    # AST debugging utilities for comparison and analysis
    class DebugHelper
      def self.compare_outputs(traditional_output, ast_output, description = 'Output comparison')
        puts "\n=== #{description} ==="

        if traditional_output == ast_output
          puts '✅ Outputs are IDENTICAL'
          return true
        else
          puts '❌ Outputs differ'
          show_diff_summary(traditional_output, ast_output)
          return false
        end
      end

      def self.compare_ast_json(ast1, ast2, description = 'AST comparison')
        puts "\n=== #{description} ==="

        json1 = ast_to_json(ast1)
        json2 = ast_to_json(ast2)

        if json1 == json2
          puts '✅ AST structures are IDENTICAL'
          return true
        else
          puts '❌ AST structures differ'
          show_json_diff(json1, json2)
          return false
        end
      end

      def self.analyze_performance(times_hash)
        puts "\n=== Performance Analysis ==="

        times_hash.each do |mode, time|
          puts "#{mode}: #{time}ms"
        end

        if times_hash.size > 1
          times = times_hash.values
          min_time = times.min
          max_time = times.max
          avg_time = times.sum / times.size.to_f

          puts "\nSummary:"
          puts "  Fastest: #{min_time}ms"
          puts "  Slowest: #{max_time}ms"
          puts "  Average: #{'%.2f' % avg_time}ms"

          if max_time > min_time
            overhead = ((max_time - min_time) / min_time.to_f * 100)
            puts "  Max overhead: #{'%.1f' % overhead}%"
          end
        end
      end

      def self.save_debug_output(content, filename)
        File.write(filename, content)
        puts "Debug output saved to: #{filename}"
      end

      def self.create_diff_files(traditional, ast, prefix = 'debug')
        traditional_file = "./tmp/#{prefix}_traditional.html"
        ast_file = "./tmp/#{prefix}_ast.html"

        # Ensure tmp directory exists
        FileUtils.mkdir_p('./tmp')

        File.write(traditional_file, traditional)
        File.write(ast_file, ast)

        puts 'Files saved for comparison:'
        puts "  Traditional: #{traditional_file}"
        puts "  AST:         #{ast_file}"
        puts "To compare: diff #{traditional_file} #{ast_file}"
      end

      def self.show_diff_summary(str1, str2)
        lines1 = str1.lines
        lines2 = str2.lines

        puts 'Size comparison:'
        puts "  Traditional: #{str1.length} characters, #{lines1.length} lines"
        puts "  AST:         #{str2.length} characters, #{lines2.length} lines"

        # Find first difference
        max_lines = [lines1.length, lines2.length].max
        first_diff_line = nil

        (0...max_lines).each do |i|
          line1 = lines1[i] || ''
          line2 = lines2[i] || ''

          if line1 != line2
            first_diff_line = i + 1
            break
          end
        end

        if first_diff_line
          puts "\nFirst difference at line #{first_diff_line}:"
          puts "  Traditional: #{(lines1[first_diff_line - 1] || '').strip}"
          puts "  AST:         #{(lines2[first_diff_line - 1] || '').strip}"
        end
      end

      def self.show_json_diff(json1, json2)
        puts 'JSON structure differences detected'

        # Simple key comparison for now
        keys1 = extract_keys(json1).sort
        keys2 = extract_keys(json2).sort

        if keys1 != keys2
          puts 'Different keys found:'
          puts "  Only in first:  #{keys1 - keys2}"
          puts "  Only in second: #{keys2 - keys1}"
        end
      end

      def self.extract_keys(obj, keys = Set.new)
        case obj
        when Hash
          obj.each do |key, value|
            keys.add(key)
            extract_keys(value, keys)
          end
        when Array
          obj.each { |item| extract_keys(item, keys) }
        end
        keys
      end

      def self.ast_to_json(ast)
        return {} unless ast

        if ast.respond_to?(:to_h)
          JSON.pretty_generate(ast.to_h)
        elsif ast.respond_to?(:to_json)
          ast.to_json
        else
          JSON.pretty_generate(ast)
        end
      end
    end
  end
end
