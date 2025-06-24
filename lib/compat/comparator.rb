# frozen_string_literal: true

require 'yaml'
require 'diff/lcs'
require 'nokogiri'

module ReVIEW
  module Compat
    class Comparator
      def initialize(format, options = {})
        @format = format
        @expected_differences = load_expected_differences
        @ignore_whitespace = options[:ignore_whitespace] || true
        @normalize_output = options[:normalize_output] || true
        @show_diff = options[:show_diff] || false
      end

      def compare(builder_output, renderer_output)
        # 正規化処理
        builder_normalized = normalize(builder_output)
        renderer_normalized = normalize(renderer_output)

        if builder_normalized == renderer_normalized
          { status: :pass, differences: [] }
        else
          differences = analyze_differences(builder_normalized, renderer_normalized)
          status = determine_status(differences)
          {
            status: status,
            differences: differences,
            builder_output: builder_output,
            renderer_output: renderer_output,
            builder_normalized: builder_normalized,
            renderer_normalized: renderer_normalized
          }
        end
      end

      private

      def load_expected_differences
        config_path = File.join(File.dirname(__FILE__), '../../config/compat_expected_differences.yml')
        if File.exist?(config_path)
          YAML.load_file(config_path)
        else
          {}
        end
      rescue StandardError => e
        warn "Warning: Could not load expected differences: #{e.message}"
        {}
      end

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

        if @ignore_whitespace
          # 連続する空白を単一スペースに
          normalized = normalized.gsub(/\s+/, ' ')
          # タグ間の空白を削除
          normalized = normalized.gsub(/>\s+</, '><')
          # 行頭・行末の空白を削除
          normalized = normalized.strip
        end

        # 改行の統一
        normalized = normalized.gsub("\r\n", "\n")

        # HTMLパースによる正規化（オプション）
        begin
          if normalized.include?('<html') || normalized.include?('<!DOCTYPE')
            # 完全なHTMLドキュメント
            doc = Nokogiri::HTML(normalized)
            normalized = doc.to_html
          elsif normalized.include?('<')
            # HTMLフラグメント
            doc = Nokogiri::HTML::DocumentFragment.parse(normalized)
            normalized = doc.to_html
          end
        rescue StandardError => e
          # HTMLパースに失敗した場合はそのまま使用
          warn "HTML parse failed: #{e.message}" if @show_diff
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
        return :pass if differences.empty?

        # 既知の差異かチェック
        if all_expected_differences?(differences)
          :pass_with_known_differences
        else
          :fail
        end
      end

      def all_expected_differences?(_differences)
        # 簡易実装：将来的により詳細な判定を追加
        expected = @expected_differences[@format] || {}
        return false if expected.empty?

        # ここで期待される差異パターンと照合
        # 現在は false を返すが、将来的に実装
        false
      end
    end
  end
end
