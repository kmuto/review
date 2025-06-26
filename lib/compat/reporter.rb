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

      def output_debug_files(result, debug_filename)
        # tmp/ディレクトリを作成
        tmp_dir = 'tmp'
        FileUtils.mkdir_p(tmp_dir)

        # 元のHTMLを出力
        File.write(File.join(tmp_dir, "#{debug_filename}_builder.html"), result[:builder_output])
        File.write(File.join(tmp_dir, "#{debug_filename}_renderer.html"), result[:renderer_output])

        # 差異情報をJSONで出力
        require 'json'
        differences_data = {
          differences: result[:differences],
          total_differences: result[:differences].size,
          builder_lines: result[:builder_output] ? result[:builder_output].lines.size : 0,
          renderer_lines: result[:renderer_output] ? result[:renderer_output].lines.size : 0
        }
        File.write(File.join(tmp_dir, "#{debug_filename}_differences.json"), JSON.pretty_generate(differences_data))

        puts "Debug files written to tmp/ for #{debug_filename}"
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

          # デバッグ用：元データをtmp/に出力
          debug_filename = "#{File.basename(result[:file], '.*')}_#{result[:format]}_#{index}"
          output_debug_files(result, debug_filename)

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
              
              /* Unified diff styles */
              .unified-diff {
                background: #f8f8f8;
                border: 1px solid #ddd;
                border-radius: 4px;
                overflow: hidden;
                font-family: 'Courier New', monospace;
                font-size: 12px;
              }
              .diff-hunk {
                margin-bottom: 10px;
              }
              .hunk-header {
                background: #e1f5fe;
                color: #0277bd;
                padding: 4px 8px;
                border-bottom: 1px solid #ccc;
                font-weight: bold;
              }
              .diff-line {
                padding: 2px 8px;
                margin: 0;
                line-height: 1.4;
                white-space: pre-wrap;
                display: flex;
                align-items: flex-start;
              }
              .diff-line.added {
                background: #e8f5e8;
              }
              .diff-line.removed {
                background: #ffe8e8;
              }
              .diff-line.context {
                background: #f9f9f9;
              }
              .diff-line {
                font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
              }
              .diff-marker {
                min-width: 20px;
                font-weight: bold;
                margin-right: 8px;
                flex-shrink: 0;
              }
              .diff-line.added .diff-marker {
                color: #2e7d32;
              }
              .diff-line.removed .diff-marker {
                color: #d32f2f;
              }
              .line-number {
                color: #666;
                text-decoration: none;
                background: rgba(0,0,0,0.05);
                padding: 1px 4px;
                border-radius: 2px;
                margin-right: 8px;
                min-width: 30px;
                text-align: right;
                display: inline-block;
                font-size: 10px;
              }
              .line-number:hover {
                background: rgba(0,0,0,0.1);
                text-decoration: underline;
              }
              .output-sections {
                display: flex;
                gap: 20px;
                margin: 20px 0;
              }
              .output-section {
                flex: 1;
                min-width: 0;
              }
              .output-container {
                border: 1px solid #ccc;
                max-height: 400px;
                overflow-y: auto;
                background: #f8f8f8;
                position: relative;
              }
              .content-wrapper {
                display: flex;
                min-height: 100%;
              }
              .line-numbers {
                background: #e8e8e8;
                color: #666;
                padding: 10px 8px 10px 8px;
                text-align: right;
                user-select: none;
                border-right: 1px solid #ccc;
                font-size: 12px;
                line-height: 1.2;
                white-space: pre-line;
                min-width: 50px;
                flex-shrink: 0;
              }
              .output-content { 
                background: #f8f8f8; 
                padding: 10px; 
                white-space: pre-wrap; 
                flex: 1;
                font-size: 12px;
                line-height: 1.2;
                min-width: 0;
                position: relative;
              }
              .line-highlight {
                position: absolute;
                left: 0;
                right: 0;
                background-color: rgba(255, 107, 107, 0.3);
                border: 2px solid #ff6b6b;
                pointer-events: none;
                z-index: 1;
                transition: opacity 0.3s ease;
              }
              .line-highlight.fade-out {
                opacity: 0;
              }
              .diff-section {
                margin: 20px 0;
              }
            </style>
          </head>
          <body>
            <h1>詳細差分レポート</h1>
            <h2>ファイル: #{result[:file]}</h2>
            <h3>フォーマット: #{result[:format]}</h3>
            <h3>ステータス: #{result[:status]}</h3>
            
            <div class="output-sections">
              <div class="output-section">
                <h3>Builder出力</h3>
                <div class="output-container">
                  <div class="content-wrapper">
                    <div class="line-numbers" id="builder-line-numbers"></div>
                    <div class="output-content" id="builder-content">#{escape_html(result[:builder_output])}</div>
                  </div>
                </div>
              </div>
            
              <div class="output-section">
                <h3>Renderer出力</h3>
                <div class="output-container">
                  <div class="content-wrapper">
                    <div class="line-numbers" id="renderer-line-numbers"></div>
                    <div class="output-content" id="renderer-content">#{escape_html(result[:renderer_output])}</div>
                  </div>
                </div>
              </div>
            </div>
            
            <div class="diff-section">
              <h3>差異詳細</h3>
              <p style="font-size: 14px; color: #666; margin-bottom: 10px;">
                ※ 行番号をクリックすると該当行がハイライトされます。
              </p>
              #{format_differences_with_links(result[:differences])}
            </div>

            <script>
              function addLineNumbers(contentId, lineNumbersId) {
                const content = document.getElementById(contentId);
                const lineNumbers = document.getElementById(lineNumbersId);
                
                if (!content || !lineNumbers) {
                  console.error('Elements not found:', contentId, lineNumbersId);
                  return;
                }
                
                // 現在表示されているコンテンツのテキストを取得
                // HTMLの実際の改行を保持するためinnerHTMLを使用し、<br>も考慮
                const htmlContent = content.innerHTML;
                const referenceText = content.textContent || content.innerText || '';
                
                // 改行で分割して行数を計算（実際の論理行に基づく）
                const lines = referenceText.split('\\n');
                
                // 空の最後の行は除外（split結果による余分な要素）
                const totalLines = lines[lines.length - 1] === '' ? lines.length - 1 : lines.length;
                
                // 行番号のテキストを生成
                const lineNumbers_array = [];
                for (let i = 1; i <= totalLines; i++) {
                  lineNumbers_array.push(i.toString().padStart(3, ' '));
                }
                
                lineNumbers.textContent = lineNumbers_array.join('\\n');
              }
              
              function highlightLine(type, lineNumber) {
                console.log('Highlighting line', lineNumber, 'in', type);
                
                const contentElement = document.getElementById(type + '-content');
                
                if (!contentElement) {
                  console.error('Could not find content element for highlighting');
                  return;
                }
                
                // 既存のハイライトを削除
                const existingHighlights = contentElement.querySelectorAll('.line-highlight');
                existingHighlights.forEach(highlight => highlight.remove());
                
                // テキストを行に分割
                const text = contentElement.textContent || '';
                const lines = text.split('\\n');
                
                if (lineNumber < 1 || lineNumber > lines.length) {
                  console.error('Line number out of range:', lineNumber, 'Total lines:', lines.length);
                  return;
                }
                
                // CSS値を取得
                const computedStyle = window.getComputedStyle(contentElement);
                const fontSize = parseFloat(computedStyle.fontSize);
                const lineHeight = parseFloat(computedStyle.lineHeight) || fontSize * 1.2;
                const paddingTop = parseFloat(computedStyle.paddingTop);
                
                // 該当行の位置を計算
                const targetLineIndex = lineNumber - 1;
                const lineTop = paddingTop + (targetLineIndex * lineHeight);
                
                // ハイライト要素を作成
                const highlight = document.createElement('div');
                highlight.className = 'line-highlight';
                highlight.style.top = lineTop + 'px';
                highlight.style.height = lineHeight + 'px';
                
                // ハイライトを追加
                contentElement.appendChild(highlight);
                
                // スクロールして該当行を表示
                const container = contentElement.closest('.output-container');
                if (container) {
                  const scrollPosition = Math.max(0, lineTop - 50); // 50pxのマージン
                  container.scrollTop = scrollPosition;
                }
                
                // ハイライトを永続化（自動削除しない）
                // クリックで他の行をハイライトした際のみ既存ハイライトは削除される
              }
              
              // DOM読み込み完了後に行番号を追加
              document.addEventListener('DOMContentLoaded', function() {
                addLineNumbers('builder-content', 'builder-line-numbers');
                addLineNumbers('renderer-content', 'renderer-line-numbers');
              });
            </script>
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

      def format_differences_with_links(differences)
        return '<p>差異はありません</p>' if differences.empty?

        # Unified diff形式で表示
        html = '<div class="unified-diff">'

        # 差異をコンテキスト付きで整理
        grouped_diffs = group_differences_with_context(differences)

        grouped_diffs.each do |group|
          html += '<div class="diff-hunk">'
          html += %Q(<div class="hunk-header">@@ -#{group[:builder_start]},#{group[:builder_count]} +#{group[:renderer_start]},#{group[:renderer_count]} @@</div>)

          group[:lines].each do |line|
            css_class = case line[:type]
                        when '+' then 'added'
                        when '-' then 'removed'
                        when ' ' then 'context'
                        else 'unchanged'
                        end

            if line[:type] == '+' || line[:type] == '-'
              # クリック可能な行番号
              target_type = line[:type] == '+' ? 'renderer' : 'builder'
              clickable_line = %Q(<a href="#" onclick="highlightLine('#{target_type}', #{line[:line_number]}); return false;" class="line-number">#{line[:line_number]}</a>)
              html += %Q(<div class="diff-line #{css_class}"><span class="diff-marker">#{line[:type]}</span>#{clickable_line} #{escape_html(line[:content])}</div>)
            else
              # コンテキスト行（行番号なし）
              html += %Q(<div class="diff-line #{css_class}"><span class="diff-marker">#{line[:type]}</span> #{escape_html(line[:content])}</div>)
            end
          end

          html += '</div>'
        end

        html += '</div>'
        html
      end

      def group_differences_with_context(differences)
        return [] if differences.empty?

        # 差異をタイプごとに分類
        added_lines = differences.select { |d| d[:type] == '+' }
        removed_lines = differences.select { |d| d[:type] == '-' }

        # 変更されたライン範囲を特定
        all_line_numbers = differences.map { |d| d[:line_number] }.uniq.sort

        groups = []
        current_start = nil
        current_end = nil

        all_line_numbers.each_with_index do |line_num, _index|
          if current_start.nil?
            current_start = line_num
            current_end = line_num
          elsif line_num <= current_end + 3 # 3行以内の間隔なら同じグループ
            current_end = line_num
          else
            # 新しいグループを作成
            groups << create_diff_group(differences, current_start, current_end)
            current_start = line_num
            current_end = line_num
          end
        end

        # 最後のグループを追加
        if current_start
          groups << create_diff_group(differences, current_start, current_end)
        end

        groups
      end

      def create_diff_group(differences, start_line, end_line)
        # このグループに含まれる差異を抽出
        group_diffs = differences.select do |d|
          d[:line_number] >= start_line && d[:line_number] <= end_line
        end

        removed_lines = group_diffs.select { |d| d[:type] == '-' }
        added_lines = group_diffs.select { |d| d[:type] == '+' }

        {
          builder_start: removed_lines.empty? ? start_line : removed_lines.first[:line_number],
          builder_count: removed_lines.size,
          renderer_start: added_lines.empty? ? start_line : added_lines.first[:line_number],
          renderer_count: added_lines.size,
          lines: group_diffs.map do |diff|
            {
              type: diff[:type],
              line_number: diff[:line_number],
              content: diff[:element]
            }
          end.sort_by { |line| [line[:line_number], line[:type] == '+' ? 1 : 0] }
        }
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
