# frozen_string_literal: true

require 'diff/lcs'
require 'nokogiri'

module ReVIEW
  module Compat
    class Comparator
      def initialize(format, options = {})
        @format = format
        @ignore_whitespace = options[:ignore_whitespace] || true
        @normalize_output = options[:normalize_output] || true
        @show_diff = options[:show_diff] || false
      end

      def compare(builder_output, renderer_output)
        # 正規化処理を無効化し、直接比較を行う
        if builder_output == renderer_output
          {
            status: :pass,
            differences: [],
            builder_output: builder_output,
            renderer_output: renderer_output
          }
        else
          differences = analyze_differences(builder_output, renderer_output)
          status = determine_status(differences)
          {
            status: status,
            differences: differences,
            builder_output: builder_output,
            renderer_output: renderer_output
          }
        end
      end

      private

      def normalize(content)
        return content unless @normalize_output

        case @format
        when 'html'
          normalize_html(content)
        when 'latex'
          normalize_latex(content)
        else
          content
        end
      end

      def normalize_html(html)
        # 基本的な正規化
        normalized = html.dup

        # 改行の統一
        normalized = normalized.gsub("\r\n", "\n")

        if @ignore_whitespace
          # 行単位で処理して行構造を保持
          lines = normalized.lines
          normalized_lines = lines.map do |line|
            # 行内の連続する空白を単一スペースに
            line_normalized = line.gsub(/[[:blank:]]+/, ' ')
            # タグ間の空白を削除（ただし改行は保持）
            line_normalized = line_normalized.gsub(/>\s*([^\n])</, '>\\1<')
            # 行頭・行末の空白を削除（改行文字は保持）
            line_normalized.strip + (line.end_with?("\n") ? "\n" : '')
          end
          normalized = normalized_lines.join
        end

        normalized
      end

      def normalize_latex(latex)
        normalized = latex.dup

        if @ignore_whitespace
          # 連続する空白を単一スペースに（ただし改行は保持）
          normalized = normalized.gsub(/[[:blank:]]+/, ' ')
          # 行頭・行末の空白を削除
          normalized = normalized.lines.map(&:strip).join("\n")
        end

        # 改行の統一
        normalized = normalized.gsub("\r\n", "\n")

        # LaTeX特有の正規化
        # コマンドの空白を統一
        normalized = normalized.gsub(/\\begin\s*\{\s*(\w+)\s*\}/, '\\begin{\1}')
        normalized = normalized.gsub(/\\end\s*\{\s*(\w+)\s*\}/, '\\end{\1}')

        # 数学モードの正規化
        normalized = normalized.gsub(/\$\s+/, '$').gsub(/\s+\$/, '$')

        # 複数の改行を2つまでに制限
        normalized.gsub(/\n{3,}/, "\n\n")
      end

      def analyze_differences(content1, content2)
        # 正規化せずに直接差分を計算
        diffs = Diff::LCS.diff(content1.lines, content2.lines)

        differences = []
        diffs.each do |diff_hunk|
          diff_hunk.each do |change|
            differences << {
              type: change.action,
              position: change.position,
              element: change.element.chomp,
              line_number: change.position + 1
            }
          end
        end

        differences
      end

      def determine_status(differences)
        differences.empty? ? :pass : :fail
      end
    end
  end
end
