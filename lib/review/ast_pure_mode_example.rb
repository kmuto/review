# frozen_string_literal: true

# Pure AST Mode Example - JSONBuilderを使わないfull ASTモードの推奨使用方法

require 'review/compiler'
require 'review/htmlbuilder'  # or any other builder
require 'review/ast/json_serializer'

module ReVIEW
  module AST
    # Pure AST Mode のための便利クラス
    class PureCompiler
      def initialize(builder_class = ReVIEW::HTMLBuilder)
        @builder_class = builder_class
      end

      # ASTとBuilderの出力を同時に取得
      def compile(chapter)
        builder = @builder_class.new
        compiler = ReVIEW::Compiler.new(builder, ast_mode: true)
        
        # コンパイル実行
        output = compiler.compile(chapter)
        ast_result = compiler.ast_result
        
        Result.new(ast_result, output, @builder_class)
      end

      # 結果を格納するクラス
      class Result
        attr_reader :ast, :output, :builder_class

        def initialize(ast, output, builder_class)
          @ast = ast
          @output = output
          @builder_class = builder_class
        end

        # AST構造をJSON化
        def to_json(pretty: true, include_metadata: false)
          options = ReVIEW::AST::JSONSerializer::Options.new(
            pretty: pretty,
            include_empty_arrays: include_metadata
          )
          ReVIEW::AST::JSONSerializer.serialize(@ast, options)
        end

        # AST構造の統計情報
        def statistics
          stats = {
            total_nodes: count_nodes(@ast),
            node_types: collect_node_types(@ast).tally,
            builder_output_size: @output.length,
            builder_type: @builder_class.name
          }
          stats
        end

        # 特定タイプのノードを検索
        def find_nodes(node_class)
          nodes = []
          find_nodes_recursive(@ast, node_class, nodes)
          nodes
        end

        # コードブロックを検索
        def code_blocks
          find_nodes(ReVIEW::AST::CodeBlockNode)
        end

        # インライン要素を検索
        def inline_elements
          find_nodes(ReVIEW::AST::InlineNode)
        end

        # 見出しを検索
        def headlines
          find_nodes(ReVIEW::AST::HeadlineNode)
        end

        private

        def count_nodes(node)
          count = 1
          if node.respond_to?(:children)
            node.children.each { |child| count += count_nodes(child) }
          end
          count
        end

        def collect_node_types(node)
          types = [node.class.name.split('::').last]
          if node.respond_to?(:children)
            node.children.each { |child| types += collect_node_types(child) }
          end
          types
        end

        def find_nodes_recursive(node, target_class, result)
          result << node if node.is_a?(target_class)
          if node.respond_to?(:children)
            node.children.each { |child| find_nodes_recursive(child, target_class, result) }
          end
        end
      end
    end
  end
end

# 使用例
if __FILE__ == $0
  require 'review/book'
  require 'review/book/chapter'
  require 'stringio'

  # 設定
  config = ReVIEW::Configure.values
  config['language'] = 'ja'
  book = ReVIEW::Book::Base.new
  book.config = config
  
  # I18n初期化
  ReVIEW::I18n.setup(config['language'])

  content = <<~EOB
    = Pure AST Example

    This demonstrates @<b>{pure AST mode} without JSONBuilder.

    //list[example][Example Code]{
    def hello
      puts @<i>{world}
    end
    //}
  EOB

  chapter = ReVIEW::Book::Chapter.new(book, 1, 'example', 'example.re', StringIO.new)
  chapter.content = content

  # Pure AST Compiler 使用
  pure_compiler = ReVIEW::AST::PureCompiler.new(ReVIEW::HTMLBuilder)
  result = pure_compiler.compile(chapter)

  puts "=== Pure AST Mode Results ==="
  puts "HTML Output length: #{result.output.length}"
  puts "AST Statistics: #{result.statistics}"
  puts "Code blocks found: #{result.code_blocks.size}"
  puts "Inline elements found: #{result.inline_elements.size}"
  puts "\nJSON AST (first 300 chars):"
  puts result.to_json[0..300]
end