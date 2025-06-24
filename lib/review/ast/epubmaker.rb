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
        @processor_type = nil
      end

      private

      # Override the build_epub method to use appropriate processor
      def build_epub
        determine_processor_type

        # Log processor selection for user feedback
        if @config['ast'] && @config['ast']['debug']
          puts "AST::EPUBMaker: Using #{@processor_type} processor"
        end

        super
      end

      # Determine which processor type to use based on configuration
      def determine_processor_type
        @processor_type = if should_use_renderer?
                            'Renderer'
                          else
                            'Builder'
                          end
      end

      # Check if Renderer should be used based on configuration
      def should_use_renderer?
        # Check ast.mode configuration
        return true if @config['ast'] && @config['ast']['mode'] == 'full'

        # Check epubmaker-specific setting
        return true if @config['epubmaker'] && @config['epubmaker']['use_ast_renderer']

        # Check ast.html_renderer setting
        return true if @config['ast'] && @config['ast']['html_renderer']

        # Check environment variable override
        return true if ENV['REVIEW_AST_EPUBMAKER'] == 'true'

        false
      end

      # Override converter creation to use Renderer when appropriate
      def create_converter(book)
        if should_use_renderer?
          create_ast_converter(book)
        else
          create_traditional_converter(book)
        end
      end

      # Create converter with AST Renderer
      def create_ast_converter(book)
        renderer = ReVIEW::Renderer::HTMLRenderer.new(
          config: @config,
          options: {
            chapter: nil, # Will be set per chapter
            book: book,
            img_math: @img_math,
            img_graph: @img_graph
          }
        )

        # Create a wrapper that makes Renderer compatible with Converter interface
        HTMLRendererConverterAdapter.new(book, renderer, @config)
      end

      # Create traditional converter with Builder
      def create_traditional_converter(book)
        ReVIEW::Converter.new(book, ReVIEW::HTMLBuilder.new(img_math: @img_math, img_graph: @img_graph))
      end

      # Override the converter creation point in build_epub
      # This method replaces the direct Converter.new call in the parent class
      def build_body(book, basedir, tmpdir)
        @converter = create_converter(book)
        super
      end
    end

    # Adapter to make HTML Renderer compatible with Converter interface
    class HTMLRendererConverterAdapter
      def initialize(book, renderer, config)
        @book = book
        @renderer = renderer
        @config = config
        @compile_errors = []
      end

      # Convert a chapter using the AST Renderer
      def convert(filename, output_path)
        chapter = find_chapter(filename)
        return false unless chapter

        begin
          # Compile chapter to AST
          compiler = ReVIEW::AST::Compiler.new(nil)
          ast_root = compiler.compile_to_ast(chapter)

          # Update renderer options with current chapter
          @renderer.instance_variable_set(:@chapter, chapter)

          # Render to HTML
          html_output = @renderer.render(ast_root)

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
