# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/epubmaker'
require 'review/ast'
require 'review/renderer/html_renderer'

module ReVIEW
  module AST
    # EPUBMaker - EPUBMaker with AST Renderer support
    #
    # This class extends EPUBMaker to support both traditional Builder and new Renderer approaches.
    # It automatically selects the appropriate processor based on configuration settings.
    class EPUBMaker < ReVIEW::EPUBMaker
      def initialize
        super
        @processor_type = 'AST/Renderer'
      end

      private

      # Override converter creation to use AST Renderer
      def create_converter(book)
        # Create a wrapper that makes Renderer compatible with Converter interface
        # Renderer will be created per chapter in the adapter
        HTMLRendererConverterAdapter.new(book)
      end

      # Override the converter creation point in build_epub
      # This method replaces the direct Converter.new call in the parent class
      def build_body(basetmpdir, yamlfile)
        @converter = create_converter(@book)
        super
      end
    end

    # Adapter to make HTML Renderer compatible with Converter interface
    class HTMLRendererConverterAdapter
      def initialize(book)
        @book = book
        @config = book.config
        @compile_errors = []
      end

      # Convert a chapter using the AST Renderer
      def convert(filename, output_path)
        chapter = find_chapter(filename)
        return false unless chapter

        begin
          # Compile chapter to AST
          compiler = ReVIEW::AST::Compiler.new
          ast_root = compiler.compile_to_ast(chapter)

          # Create renderer with current chapter
          renderer = ReVIEW::Renderer::HTMLRenderer.new(chapter)

          # Render to HTML
          html_output = renderer.render(ast_root)

          # Write output
          File.write(output_path, html_output)

          true
        rescue StandardError => e
          @compile_errors << "#{filename}: #{e.message}"
          if @config['ast'] && @config['ast']['debug']
            puts "AST Renderer Error in #{filename}: #{e.message}"
            puts e.backtrace.first(5)
          end
          false
        end
      end

      # Compatibility method for error handling
      attr_reader :compile_errors

      private

      # Find chapter object by filename
      def find_chapter(filename)
        basename = File.basename(filename, '.*')
        @book.chapters.find { |ch| File.basename(ch.path, '.*') == basename }
      end
    end
  end
end
