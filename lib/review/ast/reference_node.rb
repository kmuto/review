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
    # 従来のTextNodeの代わりに参照系InlineNodeの子ノードとして配置される。
    # このノードはイミュータブルであり、参照解決時には新しいインスタンスが作成される。
    class ReferenceNode < TextNode
      attr_reader :ref_id, :context_id, :resolved

      # @param ref_id [String] 参照ID（主要な参照先）
      # @param context_id [String] コンテキストID（章ID等、オプション）
      # @param resolved [Boolean] 参照が解決済みかどうか
      # @param resolved_content [String, nil] 解決された内容
      # @param location [Location, nil] ソースコード内の位置情報
      def initialize(ref_id, context_id = nil, resolved: false, resolved_content: nil, location: nil)
        # 解決済みの場合はresolved_contentを、未解決の場合は元の参照IDを表示
        content = if resolved && resolved_content
                    resolved_content
                  else
                    context_id ? "#{context_id}|#{ref_id}" : ref_id
                  end

        super(content: content, location: location)

        @ref_id = ref_id
        @context_id = context_id
        @resolved = resolved
      end

      # 参照が解決済みかどうかを判定
      # @return [Boolean] 解決済みの場合true
      def resolved?
        @resolved
      end

      # 解決済みの新しいReferenceNodeインスタンスを返す
      # @param resolved_content [String, nil] 解決された内容
      # @return [ReferenceNode] 解決済みの新しいインスタンス
      def with_resolved_content(resolved_content)
        self.class.new(
          @ref_id,
          @context_id,
          resolved: true,
          resolved_content: resolved_content,
          location: @location
        )
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
