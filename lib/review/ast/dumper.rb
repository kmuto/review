# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/book'
require 'json'
require_relative 'compiler'
require_relative 'json_serializer'

module ReVIEW
  module AST
    class Dumper
      attr_reader :config, :serializer_options

      def initialize(config: nil, serializer_options: nil)
        @config = config || ReVIEW::Configure.values
        @serializer_options = serializer_options || JSONSerializer::Options.new
      end

      def dump_file(path)
        unless File.exist?(path)
          raise FileNotFound, "file not found: #{path}"
        end

        book = ReVIEW::Book::Base.new(config: @config)

        dump_ast(path, book)
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
        basename = File.basename(path)
        chap = ReVIEW::Book::Chapter.new(book, nil, basename, path)

        compiler = ReVIEW::AST::Compiler.for_chapter(chap)

        ast_root = compiler.compile_to_ast(chap)

        # Serialize AST to JSON
        if ast_root
          ReVIEW::AST::JSONSerializer.serialize(ast_root, @serializer_options)
        else
          raise "Failed to generate AST for #{path}"
        end
      end
    end
  end
end
