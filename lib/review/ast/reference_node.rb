# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/text_node'

module ReVIEW
  module AST
    # ReferenceNode - 参照情報を保持するノード（InlineNodeの子ノードとして使用）
    #
    # 従来のTextNodeの代わりに参照系InlineNodeの子ノードとして配置され、
    # 参照解決時にcontentが更新される。
    class ReferenceNode < TextNode
      attr_reader :ref_id, :context_id
      attr_accessor :resolved, :location

      # @param ref_id [String] 参照ID（主要な参照先）
      # @param context_id [String] コンテキストID（章ID等、オプション）
      def initialize(ref_id, context_id = nil)
        # 初期状態では元の参照IDを表示
        initial_content = context_id ? "#{context_id}|#{ref_id}" : ref_id
        super(content: initial_content)

        @ref_id = ref_id
        @context_id = context_id
        @resolved = false
      end

      # 参照が解決済みかどうかを判定
      # @return [Boolean] 解決済みの場合true
      def resolved?
        @resolved
      end

      # 参照を解決し、内容を更新
      # @param resolved_content [String, nil] 解決された内容
      def resolve!(resolved_content)
        @content = resolved_content || @ref_id
        @resolved = true
      end

      # 未解決状態にリセット
      def reset!
        initial_content = @context_id ? "#{@context_id}|#{@ref_id}" : @ref_id
        @content = initial_content
        @resolved = false
      end

      # ノードの説明文字列
      # @return [String] デバッグ用の文字列表現
      def to_s
        id_part = @context_id ? "#{@context_id}|#{@ref_id}" : @ref_id
        status = resolved? ? "resolved: #{@content}" : 'unresolved'
        "#<ReferenceNode {#{id_part}} #{status}>"
      end
    end
  end
end
