# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/compiler'
require 'review/book'
require 'review/jsonbuilder'
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

      # Create builder and compiler with AST mode enabled
      builder = ReVIEW::JSONBuilder.new
      # Get all available elements for AST processing
      all_elements = %i[paragraph headline list listnum emlist emlistnum
                        cmd table imgtable emtable ul ol dl
                        image indepimage numberlessimage source quote
                        note memo tip info warning important caution notice
                        inline_b inline_i inline_code inline_tt inline_ruby
                        inline_href inline_kw inline_hd inline_img inline_list
                        inline_table inline_embed embed lead footnote]
      compiler = ReVIEW::Compiler.new(builder, ast_mode: true, ast_elements: all_elements)

      # Create mock chapter object
      basename = File.basename(path)
      chap = ReVIEW::Book::Chapter.new(book, nil, basename, path)
      chap.instance_variable_set(:@content, content)

      # Compile to AST
      compiler.compile(chap)

      # Get the AST root node
      ast_root = compiler.builder.instance_variable_get(:@document_node)

      # Serialize to JSON
      ReVIEW::AST::JSONSerializer.serialize(ast_root, @serializer_options)
    end

    def dump_with_builder(path, book)
      # Use JSONBuilder to process the file
      content = File.read(path)

      # Create compiler with JSONBuilder
      builder = ReVIEW::JSONBuilder.new
      compiler = ReVIEW::Compiler.new(builder)

      # Create mock chapter object
      basename = File.basename(path)
      chap = ReVIEW::Book::Chapter.new(book, nil, basename, path)
      chap.instance_variable_set(:@content, content)

      # Compile
      compiler.compile(chap)

      # Return builder result
      builder.result
    end
  end
end
