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
    # PdfMaker - PDFMaker with AST Renderer support
    #
    # This class extends PDFMaker to support both traditional Builder and new Renderer approaches.
    # It automatically selects the appropriate processor based on configuration settings.
    class PdfMaker < ReVIEW::PDFMaker
      def initialize
        super
        @processor_type = nil
        @compile_errors_list = []
      end

      # Override check_compile_status to provide detailed error information
      def check_compile_status(ignore_errors)
        # Check for errors in both main class and adapter
        has_errors = @compile_errors || (@renderer_adapter && @renderer_adapter.any_errors?)
        return unless has_errors

        # Set the compile_errors flag for parent class compatibility
        @compile_errors = true

        # Output detailed error summary
        if summary = compilation_error_summary
          @logger.error summary
        end

        super
      end

      # Provide summary of all compilation errors
      def compilation_error_summary
        errors = @compile_errors_list.dup
        errors.concat(@renderer_adapter.compile_errors_list) if @renderer_adapter

        return nil if errors.empty?

        summary = ["Compilation errors occurred in #{errors.length} file(s):"]
        errors.each_with_index do |error, i|
          summary << "  #{i + 1}. #{error}"
        end
        summary.join("\n")
      end

      private

      # Override the build_pdf method to use appropriate processor
      def build_pdf
        # Log processor selection for user feedback
        if @config['ast'] && @config['ast']['debug']
          puts "AST::PdfMaker: Using #{@processor_type} processor"
        end

        super
      end

      # Override converter creation to use Renderer when appropriate
      def create_converter(book)
        # Create a wrapper that makes Renderer compatible with Converter interface
        # Renderer will be created per chapter in the adapter
        @renderer_adapter = RendererConverterAdapter.new(book)
      end

      # Override the converter creation point in build_pdf
      # This method replaces the direct Converter.new call in the parent class
      def make_input_files(book)
        @converter = create_converter(book)

        # AST environment uses AST::Indexer instead of traditional builder-based indexing
        # No need to call generate_indexes - AST::Indexer handles indexing during rendering

        super
      end
    end

    # Adapter to make Renderer compatible with Converter interface
    class RendererConverterAdapter
      attr_reader :compile_errors_list

      def initialize(book)
        @book = book
        @config = book.config
        @compile_errors = false
        @compile_errors_list = []
        @logger = ReVIEW.logger
      end

      def any_errors?
        @compile_errors || !@compile_errors_list.empty?
      end

      # Convert a chapter using the AST Renderer
      def convert(filename, output_path)
        chapter = find_chapter(filename)
        return false unless chapter

        begin
          # AST environment uses AST::Indexer for indexing during rendering
          # No need to call generate_indexes - AST::Indexer handles it in visit_document

          # Compile chapter to AST using auto-detection for file format
          compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
          ast_root = compiler.compile_to_ast(chapter)

          # Create renderer with current chapter
          renderer = ReVIEW::Renderer::LatexRenderer.new(chapter)

          # Render to LaTeX (AST::Indexer will handle indexing during this process)
          latex_output = renderer.render(ast_root)

          # Write output
          File.write(output_path, latex_output)

          true
        rescue ReVIEW::CompileError, ReVIEW::SyntaxError, ReVIEW::InlineTokenizeError => e
          # These are known ReVIEW compilation errors - handle them specifically
          error_message = "#{filename}: #{e.class.name} - #{e.message}"
          @compile_errors_list << error_message
          @compile_errors = true

          @logger.error "Compilation error in #{filename}: #{e.message}"

          # Show location information if available
          if e.respond_to?(:location) && e.location
            @logger.error "  at line #{e.location.lineno} in #{e.location.filename}"
          end

          # Show backtrace in debug mode
          if @config['ast'] && @config['ast']['debug']
            @logger.debug('Backtrace:')
            e.backtrace.first(10).each { |line| @logger.debug("  #{line}") }
          end

          false
        rescue StandardError => e
          error_message = "#{filename}: #{e.message}"
          @compile_errors_list << error_message
          @compile_errors = true # Set flag for parent class compatibility

          # Always output error to user, not just in debug mode
          @logger.error "AST Renderer Error in #{filename}: #{e.message}"

          # Show backtrace in debug mode
          if @config['ast'] && @config['ast']['debug']
            @logger.debug('Backtrace:')
            e.backtrace.first(10).each { |line| @logger.debug("  #{line}") }
          end

          false
        end
      end

      private

      # Find chapter or part object by filename
      def find_chapter(filename)
        basename = File.basename(filename, '.*')

        # First check chapters
        chapter = @book.chapters.find { |ch| File.basename(ch.path, '.*') == basename }
        return chapter if chapter

        # Then check parts with content files
        @book.parts_in_file.find { |part| File.basename(part.path, '.*') == basename }
      end
    end
  end
end
