# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/compiler'
require 'review/book'
require 'review/htmlbuilder'
require 'review/ast/json_serializer'
require 'json'

module ReVIEW
  class Dumper
    attr_reader :config, :mode, :serializer_options

    def initialize(config: nil, mode: :ast, serializer_options: nil)
      @config = config || ReVIEW::Configure.values
      @mode = mode
      @serializer_options = serializer_options || AST::JSONSerializer::Options.new
    end

    def dump_file(path)
      unless File.exist?(path)
        raise FileNotFound, "file not found: #{path}"
      end

      book = ReVIEW::Book::Base.new(config: @config)

      if @mode == :ast
        dump_ast(path, book)
      else
        dump_with_builder(path, book)
      end
    end

    def dump_files(paths)
      results = {}
      paths.each do |path|
        results[path] = dump_file(path)
      end
      results
    end

    private

    def dump_ast(path, book)
      # Create a temporary chapter for standalone file
      content = File.read(path)

      # Create builder and compiler with Pure AST mode
      # Use HTMLBuilder as a dummy builder since we only need AST
      builder = ReVIEW::HTMLBuilder.new
      compiler = ReVIEW::Compiler.new(builder, ast_mode: true)

      # Create mock chapter object
      basename = File.basename(path)
      chap = ReVIEW::Book::Chapter.new(book, nil, basename, path)
      chap.instance_variable_set(:@content, content)

      # Compile to AST
      compiler.compile(chap)

      # Get the AST root node from the compiler
      ast_root = compiler.ast_result

      # Serialize AST to JSON
      if ast_root
        ReVIEW::AST::JSONSerializer.serialize(ast_root, @serializer_options)
      else
        raise "Failed to generate AST for #{path}"
      end
    end

    def dump_with_builder(path, book)
      # Legacy mode: use AST mode for consistency
      # This method is deprecated - use dump_ast instead
      dump_ast(path, book)
    end
  end
end
