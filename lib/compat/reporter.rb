# frozen_string_literal: true

require 'erb'
require 'json'
require 'fileutils'

module ReVIEW
  module Compat
    class Reporter
      def initialize(output_dir = 'reports/compat')
        @output_dir = output_dir
        @results = []
        ensure_output_directory
      end

      def add_result(file, format, comparison_result)
        @results << {
          file: file,
          format: format,
          status: comparison_result[:status],
          differences: comparison_result[:differences],
          builder_output: comparison_result[:builder_output],
          renderer_output: comparison_result[:renderer_output],
          timestamp: Time.now
        }
      end

      def generate_reports
        generate_summary_json
        generate_summary_html
        generate_detailed_reports
        generate_markdown_summary
      end

      def summary
        total = @results.length
        passed = @results.count { |r| r[:status] == :pass }
        known_diff = @results.count { |r| r[:status] == :pass_with_known_differences }
        failed = @results.count { |r| r[:status] == :fail }

        {
          total: total,
          passed: passed,
          known_differences: known_diff,
          failed: failed,
          success_rate: total > 0 ? ((passed + known_diff) * 100.0 / total).round(2) : 0
        }
      end

      private

      def ensure_output_directory
        FileUtils.mkdir_p(@output_dir)
        FileUtils.mkdir_p(File.join(@output_dir, 'detailed'))
      end

      def generate_summary_json
        summary_data = {
          summary: summary,
          results: @results.map do |result|
            {
              file: result[:file],
              format: result[:format],
              status: result[:status],
              differences_count: result[:differences].length,
              timestamp: result[:timestamp]
            }
          end,
          generated_at: Time.now
        }

        File.write(
          File.join(@output_dir, 'summary.json'),
          JSON.pretty_generate(summary_data)
        )
      end

      def generate_summary_html
        template = html_template

        # データを準備
        results_by_file = group_results_by_file

        # ERBでテンプレートを処理
        erb = ERB.new(template)
        html_content = erb.result(binding)

        File.write(File.join(@output_dir, 'summary.html'), html_content)
      end

      def generate_detailed_reports
        @results.each_with_index do |result, index|
          next unless result[:status] == :fail

          filename = "#{File.basename(result[:file], '.*')}_#{result[:format]}_#{index}.html"

          detailed_content = generate_detailed_html(result)
          File.write(File.join(@output_dir, 'detailed', filename), detailed_content)
        end
      end

      def generate_markdown_summary
        summary_stats = summary

        markdown = <<~MARKDOWN
          # 互換性チェック結果

          ## サマリー
          - 総チェック数: #{summary_stats[:total]}
          - 成功: #{summary_stats[:passed]}
          - 既知の差異: #{summary_stats[:known_differences]}
          - 失敗: #{summary_stats[:failed]}
          - 成功率: #{summary_stats[:success_rate]}%

          ## 詳細結果
          | ファイル | フォーマット | ステータス | 差異数 |
          |---------|-------------|-----------|--------|
        MARKDOWN

        @results.each do |result|
          status_emoji = case result[:status]
                         when :pass then '✅'
                         when :pass_with_known_differences then '⚠️'
                         when :fail then '❌'
                         else '❓'
                         end

          markdown += "| #{result[:file]} | #{result[:format]} | #{status_emoji} #{result[:status]} | #{result[:differences].length} |\n"
        end

        File.write(File.join(@output_dir, 'summary.md'), markdown)
      end

      def group_results_by_file
        grouped = {}
        @results.each do |result|
          file = result[:file]
          grouped[file] ||= {}
          grouped[file][result[:format]] = result
        end
        grouped
      end

      def generate_detailed_html(result)
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <title>詳細差分: #{result[:file]} (#{result[:format]})</title>
            <style>
              body { font-family: monospace; margin: 20px; }
              .diff { background: #f8f8f8; padding: 10px; margin: 10px 0; }
              .added { background: #90EE90; }
              .removed { background: #FFB6C1; }
              .unchanged { background: #f0f0f0; }
              .output-section { margin: 20px 0; }
              .output-content { 
                background: #f8f8f8; 
                padding: 10px; 
                white-space: pre-wrap; 
                border: 1px solid #ccc; 
                max-height: 400px;
                overflow-y: auto;
              }
            </style>
          </head>
          <body>
            <h1>詳細差分レポート</h1>
            <h2>ファイル: #{result[:file]}</h2>
            <h3>フォーマット: #{result[:format]}</h3>
            <h3>ステータス: #{result[:status]}</h3>
            
            <div class="output-section">
              <h3>Builder出力</h3>
              <div class="output-content">#{escape_html(result[:builder_output])}</div>
            </div>
            
            <div class="output-section">
              <h3>Renderer出力</h3>
              <div class="output-content">#{escape_html(result[:renderer_output])}</div>
            </div>
            
            <div class="output-section">
              <h3>差異詳細</h3>
              #{format_differences(result[:differences])}
            </div>
          </body>
          </html>
        HTML
      end

      def format_differences(differences)
        return '<p>差異はありません</p>' if differences.empty?

        html = '<div class="diff">'
        differences.each do |diff|
          css_class = case diff[:type]
                      when '+' then 'added'
                      when '-' then 'removed'
                      else 'unchanged'
                      end

          html += %Q(<div class="#{css_class}">#{diff[:type]} #{diff[:line_number]}: #{escape_html(diff[:element])}</div>)
        end
        html += '</div>'
        html
      end

      def escape_html(text)
        text.to_s.
          gsub('&', '&amp;').
          gsub('<', '&lt;').
          gsub('>', '&gt;').
          gsub('"', '&quot;').
          gsub("'", '&#39;')
      end

      def html_template
        <<~HTML
          <!DOCTYPE html>
          <html>
          <head>
            <title>Re:VIEW 互換性チェック結果</title>
            <style>
              body { font-family: Arial, sans-serif; margin: 20px; }
              .pass { background-color: #90EE90; padding: 5px; }
              .fail { background-color: #FFB6C1; padding: 5px; }
              .pass_with_known_differences { background-color: #FFFFE0; padding: 5px; }
              .summary { margin: 20px 0; padding: 20px; border: 1px solid #ccc; }
              table { border-collapse: collapse; width: 100%; }
              th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
              th { background-color: #f2f2f2; }
              .file-section { margin: 20px 0; }
            </style>
          </head>
          <body>
            <h1>Re:VIEW Builder/Renderer 互換性チェック結果</h1>
            
            <div class="summary">
              <h2>サマリー</h2>
              <ul>
                <li>総チェック数: <%= summary[:total] %></li>
                <li>成功: <%= summary[:passed] %></li>
                <li>既知の差異: <%= summary[:known_differences] %></li>
                <li>失敗: <%= summary[:failed] %></li>
                <li>成功率: <%= summary[:success_rate] %>%</li>
              </ul>
            </div>
            
            <h2>詳細結果</h2>
            <% results_by_file.each do |file, formats| %>
              <div class="file-section">
                <h3><%= file %></h3>
                <table>
                  <thead>
                    <tr>
                      <th>フォーマット</th>
                      <th>ステータス</th>
                      <th>差異数</th>
                      <th>詳細</th>
                    </tr>
                  </thead>
                  <tbody>
                    <% formats.each do |format, result| %>
                    <tr>
                      <td><%= format %></td>
                      <td class="<%= result[:status] %>"><%= result[:status] %></td>
                      <td><%= result[:differences].length %></td>
                      <td>
                        <% if result[:status] == :fail %>
                          <a href="detailed/<%= File.basename(result[:file], '.*') %>_<%= result[:format] %>_<%= @results.index(result) %>.html">詳細</a>
                        <% else %>
                          -
                        <% end %>
                      </td>
                    </tr>
                    <% end %>
                  </tbody>
                </table>
              </div>
            <% end %>
            
            <footer>
              <p>生成日時: <%= Time.now.strftime('%Y-%m-%d %H:%M:%S') %></p>
            </footer>
          </body>
          </html>
        HTML
      end
    end
  end
end
