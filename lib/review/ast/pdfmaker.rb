# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/pdfmaker'
require 'review/ast'
require 'review/renderer/latex_renderer'

module ReVIEW
  module AST
    # PDFMaker - PDFMaker with AST Renderer support
    #
    # This class extends PDFMaker to support both traditional Builder and new Renderer approaches.
    # It automatically selects the appropriate processor based on configuration settings.
    class PDFMaker < ReVIEW::PDFMaker
      def initialize
        super
        @processor_type = nil
      end

      private

      # Override the build_pdf method to use appropriate processor
      def build_pdf
        # Log processor selection for user feedback
        if @config['ast'] && @config['ast']['debug']
          puts "AST::PDFMaker: Using #{@processor_type} processor"
        end

        super
      end

      # Override converter creation to use Renderer when appropriate
      def create_converter(book)
        # Create a wrapper that makes Renderer compatible with Converter interface
        # Renderer will be created per chapter in the adapter
        RendererConverterAdapter.new(book)
      end

      # Override the converter creation point in build_pdf
      # This method replaces the direct Converter.new call in the parent class
      def make_input_files(book)
        @converter = create_converter(book)

        # Ensure all chapter indexes are generated before conversion
        book.chapters.each(&:generate_indexes)
        book.generate_indexes

        super
      end
    end

    # Adapter to make Renderer compatible with Converter interface
    class RendererConverterAdapter
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
          # Ensure chapter indexes are generated before AST compilation
          chapter.generate_indexes

          # Compile chapter to AST using auto-detection for file format
          compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
          ast_root = compiler.compile_to_ast(chapter)

          # Create renderer with current chapter
          renderer = ReVIEW::Renderer::LATEXRenderer.new(chapter)

          # Render to LaTeX
          latex_output = renderer.render(ast_root)

          # Write output
          File.write(output_path, latex_output)

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
