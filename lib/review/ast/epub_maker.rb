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
    # EpubMaker - EPUBMaker with AST Renderer support
    #
    # This class extends EPUBMaker to support both traditional Builder and new Renderer approaches.
    # It automatically selects the appropriate processor based on configuration settings.
    class EpubMaker < ReVIEW::EPUBMaker
      def initialize
        super
        @processor_type = 'AST/Renderer'
      end

      private

      # Override converter creation to use AST Renderer
      def create_converter(book)
        # Create a wrapper that makes Renderer compatible with Converter interface
        # Renderer will be created per chapter in the adapter
        HtmlRendererConverterAdapter.new(book)
      end

      # Override build_body to use AST Renderer instead of traditional Builder
      # This is a complete override of the parent's build_body method,
      # replacing only the converter creation part
      def build_body(basetmpdir, yamlfile)
        @precount = 0
        @bodycount = 0
        @postcount = 0

        @manifeststr = ''
        @ncxstr = ''
        @tocdesc = []
        @img_graph = ReVIEW::ImgGraph.new(@config, 'html', path_name: '_review_graph')

        basedir = File.dirname(yamlfile)
        base_path = Pathname.new(basedir)
        book = ReVIEW::Book::Base.new(basedir, config: @config)

        # Use AST Renderer instead of traditional Builder
        @converter = create_converter(book)
        @compile_errors = nil

        book.parts.each do |part|
          if part.name.present?
            if part.file?
              build_chap(part, base_path, basetmpdir, true)
            else
              htmlfile = "part_#{part.number}.#{@config['htmlext']}"
              build_part(part, basetmpdir, htmlfile)
              title = ReVIEW::I18n.t('part', part.number)
              if part.name.strip.present?
                title += ReVIEW::I18n.t('chapter_postfix') + part.name.strip
              end
              @htmltoc.add_item(0, htmlfile, title, chaptype: 'part')
              write_buildlogtxt(basetmpdir, htmlfile, '')
            end
          end

          part.chapters.each do |chap|
            build_chap(chap, base_path, basetmpdir, false)
          end
        end
        check_compile_status

        begin
          @img_graph.make_mermaid_images
        rescue ApplicationError => e
          error! e.message
        end
        @img_graph.cleanup_graphimg
      end
    end

    # Adapter to make HTML Renderer compatible with Converter interface
    class HtmlRendererConverterAdapter
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
          # Compile chapter to AST using auto-detection for file format
          compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
          ast_root = compiler.compile_to_ast(chapter)

          # Create renderer with current chapter
          renderer = ReVIEW::Renderer::HtmlRenderer.new(chapter)

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
