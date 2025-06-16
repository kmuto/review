# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast/config'

module ReVIEW
  module AST
    # CompilerAdapter - Adapter for creating Compiler instances with AST configuration
    #
    # This class handles:
    # - Creating Compiler instances with AST configuration
    # - Special handling for JSON target to ensure AST mode
    # - Configuration-based compiler option setup
    class CompilerAdapter
      def initialize(config = nil)
        @config = config || ReVIEW::Configure.values
      end

      # Create a compiler instance with appropriate options
      def create_compiler(builder, target = nil)
        compiler_options = compiler_options_for(target)
        ReVIEW::Compiler.new(builder, **compiler_options)
      end

      # Get compiler options based on configuration and target
      def compiler_options_for(target = nil)
        ast_config = ReVIEW::AST::Config.new(@config)
        compiler_options = ast_config.compiler_options

        # Override for JSON target to ensure proper location tracking
        if target == 'json' && compiler_options[:ast_mode] == false
          compiler_options = { ast_mode: true }
        end

        compiler_options
      end

      # Create a traditional (non-AST) compiler
      def create_traditional_compiler(builder)
        ReVIEW::Compiler.new(builder, ast_mode: false)
      end

      # Create a full AST mode compiler
      def create_ast_compiler(builder)
        ReVIEW::Compiler.new(builder, ast_mode: true)
      end
    end
  end
end
