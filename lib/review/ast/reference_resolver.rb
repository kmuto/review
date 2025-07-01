# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/reference_node'
require 'review/ast/inline_node'
require 'review/ast/indexer'
require 'review/exception'

module ReVIEW
  module AST
    # ReferenceResolver - 参照解決の専門クラス
    #
    # ASTに含まれるReferenceNodeを走査し、インデックス情報を使用して
    # 適切な参照内容に解決する。
    class ReferenceResolver
      def initialize(chapter)
        @chapter = chapter
        @book = chapter.book
        @logger = ReVIEW.logger
      end

      # ASTのReferenceNodeを解決
      def resolve_references(ast)
        # まずインデックスを構築（既存の仕組みを使用）
        build_indexes_if_needed(ast)

        # InlineNodeを走査してその子のReferenceNodeを解決
        resolve_count = 0
        error_count = 0

        visit_all_nodes(ast) do |node|
          if node.is_a?(InlineNode) && has_reference_children?(node)
            ref_type = node.inline_type
            node.children.each do |child|
              if child.is_a?(ReferenceNode) && !child.resolved?
                if resolve_node(child, ref_type)
                  resolve_count += 1
                else
                  error_count += 1
                end
              end
            end
          end
        end

        @logger.debug("ReferenceResolver: #{resolve_count} references resolved, #{error_count} failed") if @logger
        { resolved: resolve_count, failed: error_count }
      end

      private

      # InlineNodeが参照系でReferenceNodeの子を持つかチェック
      def has_reference_children?(inline_node)
        return false unless inline_node.inline_type

        # 参照系のinline_typeをチェック
        ref_types = %w[img list table eq fn endnote hd chap chapref sec secref labelref ref]
        return false unless ref_types.include?(inline_node.inline_type)

        # ReferenceNodeの子を持つかチェック
        inline_node.children&.any?(ReferenceNode)
      end

      # インデックスが構築されていなければ構築
      def build_indexes_if_needed(ast)
        unless @chapter.instance_variable_get(:@footnote_index)
          indexer = Indexer.new(@chapter)
          indexer.build_indexes(ast)

          # インデックスをチャプターに設定
          @chapter.instance_variable_set(:@footnote_index, indexer.footnote_index)
          @chapter.instance_variable_set(:@endnote_index, indexer.endnote_index)
          @chapter.instance_variable_set(:@list_index, indexer.list_index)
          @chapter.instance_variable_set(:@table_index, indexer.table_index)
          @chapter.instance_variable_set(:@equation_index, indexer.equation_index)
          @chapter.instance_variable_set(:@image_index, indexer.image_index)
          @chapter.instance_variable_set(:@icon_index, indexer.icon_index)
          @chapter.instance_variable_set(:@numberless_image_index, indexer.numberless_image_index)
          @chapter.instance_variable_set(:@indepimage_index, indexer.indepimage_index)
          @chapter.instance_variable_set(:@headline_index, indexer.headline_index)
          @chapter.instance_variable_set(:@column_index, indexer.column_index)
          @chapter.instance_variable_set(:@bibpaper_index, indexer.bibpaper_index)
        end
      end

      # ReferenceNodeを解決（ref_typeは親InlineNodeから取得）
      def resolve_node(node, ref_type)
        content = case ref_type
                  when 'img' then resolve_image_ref(node.ref_id)
                  when 'table' then resolve_table_ref(node.ref_id)
                  when 'list' then resolve_list_ref(node.ref_id)
                  when 'eq' then resolve_equation_ref(node.ref_id)
                  when 'fn' then resolve_footnote_ref(node.ref_id)
                  when 'endnote' then resolve_endnote_ref(node.ref_id)
                  when 'chap' then resolve_chapter_ref(node.ref_id)
                  when 'chapref' then resolve_chapter_ref_with_title(node.ref_id)
                  when 'hd' then resolve_headline_ref(node.ref_id)
                  when 'sec', 'secref' then resolve_section_ref(node.ref_id)
                  when 'labelref', 'ref' then resolve_label_ref(node.ref_id)
                  else
                    raise CompileError, "Unknown reference type: #{ref_type}"
                  end

        node.resolve!(content)
        !content.nil?
      end

      # ASTの全ノードを走査
      def visit_all_nodes(node, &block)
        yield node if block

        if node.respond_to?(:children) && node.children
          node.children.each { |child| visit_all_nodes(child, &block) }
        end
      end

      # 図参照の解決
      def resolve_image_ref(id)
        if @chapter.image_index && @chapter.image_index.number(id)
          "図#{@chapter.number}.#{@chapter.image_index.number(id)}"
        else
          raise CompileError, "Image reference not found: #{id}"
        end
      end

      # 表参照の解決
      def resolve_table_ref(id)
        if @chapter.table_index && @chapter.table_index.number(id)
          "表#{@chapter.number}.#{@chapter.table_index.number(id)}"
        else
          raise CompileError, "Table reference not found: #{id}"
        end
      end

      # リスト参照の解決
      def resolve_list_ref(id)
        if @chapter.list_index && @chapter.list_index.number(id)
          "リスト#{@chapter.number}.#{@chapter.list_index.number(id)}"
        else
          raise CompileError, "List reference not found: #{id}"
        end
      end

      # 数式参照の解決
      def resolve_equation_ref(id)
        if @chapter.equation_index && @chapter.equation_index.number(id)
          "式#{@chapter.number}.#{@chapter.equation_index.number(id)}"
        else
          raise CompileError, "Equation reference not found: #{id}"
        end
      end

      # 脚注参照の解決
      def resolve_footnote_ref(id)
        if @chapter.footnote_index && @chapter.footnote_index.number(id)
          @chapter.footnote_index.number(id).to_s
        else
          raise CompileError, "Footnote reference not found: #{id}"
        end
      end

      # 後注参照の解決
      def resolve_endnote_ref(id)
        if @chapter.endnote_index && @chapter.endnote_index.number(id)
          @chapter.endnote_index.number(id).to_s
        else
          raise CompileError, "Endnote reference not found: #{id}"
        end
      end

      # 章参照の解決
      def resolve_chapter_ref(id)
        if @book
          chapter = @book.chapter_by_id(id)
          if chapter
            "第#{chapter.number}章"
          else
            raise CompileError, "Chapter reference not found: #{id}"
          end
        else
          raise CompileError, "Book not available for chapter reference: #{id}"
        end
      end

      # 章タイトル付き参照の解決
      def resolve_chapter_ref_with_title(id)
        if @book
          chapter = @book.chapter_by_id(id)
          if chapter
            "第#{chapter.number}章「#{chapter.title}」"
          else
            raise CompileError, "Chapter reference not found: #{id}"
          end
        else
          raise CompileError, "Book not available for chapter reference: #{id}"
        end
      end

      # 見出し参照の解決
      def resolve_headline_ref(id)
        # TODO: 見出し参照の実装（現在は仮実装）
        "「#{id}」"
      end

      # セクション参照の解決
      def resolve_section_ref(id)
        # TODO: セクション参照の実装（現在は仮実装）
        id.to_s
      end

      # ラベル参照の解決
      def resolve_label_ref(id)
        # TODO: ラベル参照の実装（現在は仮実装）
        id.to_s
      end
    end
  end
end
