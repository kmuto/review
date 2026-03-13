# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/textmaker'
require 'review/ast'
require 'review/renderer/top_renderer'
require 'review/renderer/plaintext_renderer'

module ReVIEW
  module AST
    module Command
      # TextMaker - TEXTMaker with AST Renderer support
      #
      # This class extends TEXTMaker to support both traditional Builder and new Renderer approaches.
      # It automatically selects the appropriate processor based on configuration settings.
      class TextMaker < ReVIEW::TEXTMaker
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

          super if defined?(super)
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

        # Override build_body to use Renderer
        def build_body(basetmpdir, _yamlfile)
          # Build indexes for all chapters to support cross-chapter references
          # This must be done before rendering any chapter
          require_relative('../book_indexer')
          ReVIEW::AST::BookIndexer.build(@book)

          @converter = create_converter(@book)

          base_path = Pathname.new(@basedir)
          @book.parts.each do |part|
            if part.name.present?
              if part.file?
                build_chap(part, base_path, basetmpdir, true)
              else
                textfile = "part_#{part.number}.txt"
                build_part(part, basetmpdir, textfile)
              end
            end

            part.chapters.each { |chap| build_chap(chap, base_path, basetmpdir, false) }
          end
        end

        # Create a converter that uses Renderer
        def create_converter(book)
          @renderer_adapter = RendererConverterAdapter.new(book, @plaintext)
        end
      end

      # Adapter to make Renderer compatible with Converter interface
      class RendererConverterAdapter
        attr_reader :compile_errors_list

        def initialize(book, plaintext)
          @book = book
          @config = book.config
          @plaintext = plaintext
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
            # Compile chapter to AST using auto-detection for file format
            compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
            ast_root = compiler.compile_to_ast(chapter)

            # Create renderer with current chapter
            renderer = if @plaintext
                         ReVIEW::Renderer::PlaintextRenderer.new(chapter)
                       else
                         ReVIEW::Renderer::TopRenderer.new(chapter)
                       end

            # Render to text
            text_output = renderer.render(ast_root)

            # Write output
            File.write(output_path, text_output)

            true
          rescue ReVIEW::CompileError, ReVIEW::SyntaxError, ReVIEW::AST::InlineTokenizeError => e
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
            if @config['debug']
              @logger.debug('Backtrace:')
              e.backtrace.first(10).each { |line| @logger.debug("  #{line}") }
            end

            false
          rescue StandardError => e
            error_message = "#{filename}: #{e.message}"
            @compile_errors_list << error_message
            @compile_errors = true

            # Always output error to user, not just in debug mode
            @logger.error "AST Renderer Error in #{filename}: #{e.message}"

            # Show first backtrace line to help identify the issue
            if e.backtrace && !e.backtrace.empty?
              @logger.error "  at #{e.backtrace.first}"
            end

            # Show full backtrace in debug mode
            if @config['debug']
              @logger.error('Full Backtrace:')
              e.backtrace.first(20).each { |line| @logger.error("  #{line}") }
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
end
