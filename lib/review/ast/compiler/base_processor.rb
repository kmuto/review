# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/node'
require 'review/ast/block_node'
require 'review/ast/table_node'

module ReVIEW
  module AST
    class Compiler
      # Abstract class
      class BaseProcessor
        def self.process(ast_root, chapter:, compiler:)
          new(chapter: chapter, compiler: compiler).process(ast_root)
        end

        def initialize(chapter:, compiler:)
          @chapter = chapter
          @compiler = compiler
        end

        def process(ast_root)
          process_node(ast_root)
        end

        private

        def process_node(_node)
          raise NotImplementedError
        end
      end
    end
  end
end
