# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/idgxmlmaker'
require 'review/ast'
require 'review/ast/indexer'
require 'review/renderer/idgxml_renderer'

module ReVIEW
  module AST
    class IdgxmlMaker < ReVIEW::IDGXMLMaker
      def initialize
        super
        @processor_type = 'AST/Renderer'
        @renderer_adapter = nil
      end

      private

      def build_body(basetmpdir, yamlfile) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
        base_path = Pathname.new(@basedir)
        book = @book || ReVIEW::Book::Base.new(@basedir, config: @config)

        if @config.dig('ast', 'debug')
          puts "AST::IdgxmlMaker: Using #{@processor_type} processor"
        end

        ReVIEW::AST::Indexer.build_book_indexes(book)

        @renderer_adapter = create_converter(book)
        @converter = @renderer_adapter
        @compile_errors = false

        book.parts.each do |part|
          if part.name.present?
            if part.file?
              build_chap(part, base_path, basetmpdir, true)
            else
              xmlfile = "part_#{part.number}.xml"
              build_part(part, basetmpdir, xmlfile)
            end
          end
          part.chapters.each do |chap|
            build_chap(chap, base_path, basetmpdir, false)
          end
        end

        report_renderer_errors
      end

      def build_chap(chap, base_path, basetmpdir, ispart)
        filename = if ispart.present?
                     chap.path
                   else
                     Pathname.new(chap.path).relative_path_from(base_path).to_s
                   end
        id = File.basename(filename).sub(/\.re\Z/, '')
        if @buildonly && !@buildonly.include?(id)
          warn "skip #{id}.re"
          return
        end

        xmlfile = "#{id}.xml"
        output_path = File.join(basetmpdir, xmlfile)
        success = @converter.convert(filename, output_path)
        if success
          apply_filter(output_path)
        else
          @compile_errors = true
        end
      rescue StandardError => e
        @compile_errors = true
        error "compile error in #{filename} (#{e.class})"
        error e.message
      end

      def create_converter(book)
        RendererConverterAdapter.new(
          book,
          img_math: @img_math,
          img_graph: @img_graph,
          config: @config,
          logger: @logger
        )
      end

      def report_renderer_errors
        return unless @renderer_adapter&.any_errors?

        @compile_errors = true
        summary = @renderer_adapter.compilation_error_summary
        @logger.error(summary) if summary
      end
    end

    class RendererConverterAdapter
      attr_reader :compile_errors_list

      def initialize(book, img_math:, img_graph:, config:, logger:)
        @book = book
        @img_math = img_math
        @img_graph = img_graph
        @config = config
        @logger = logger
        @compile_errors_list = []
      end

      def convert(filename, output_path)
        chapter = find_chapter(filename)
        unless chapter
          record_error("#{filename}: chapter not found")
          return false
        end

        compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
        ast_root = compiler.compile_to_ast(chapter)

        renderer = ReVIEW::Renderer::IdgxmlRenderer.new(chapter)
        inject_shared_resources(renderer)

        xml_output = renderer.render(ast_root)
        File.write(output_path, xml_output)

        true
#      rescue ReVIEW::CompileError, ReVIEW::SyntaxError, ReVIEW::AST::InlineTokenizeError => e
#        handle_known_error(filename, e)
#        false
#      rescue StandardError => e
#        handle_unexpected_error(filename, e)
#        false
      end

      def any_errors?
        !@compile_errors_list.empty?
      end

      def compilation_error_summary
        return nil if @compile_errors_list.empty?

        summary = ["Compilation errors occurred in #{@compile_errors_list.length} file(s):"]
        @compile_errors_list.each_with_index do |error, i|
          summary << "  #{i + 1}. #{error}"
        end
        summary.join("\n")
      end

      private

      def inject_shared_resources(renderer)
        renderer.instance_variable_set(:@img_math, @img_math) if @img_math
        renderer.instance_variable_set(:@img_graph, @img_graph) if @img_graph
      end

      def find_chapter(filename)
        basename = File.basename(filename, '.*')

        chapter = @book.chapters.find { |ch| File.basename(ch.path, '.*') == basename }
        return chapter if chapter

        @book.parts_in_file.find { |part| File.basename(part.path, '.*') == basename }
      end

      def handle_known_error(filename, error)
        message = "#{filename}: #{error.class.name} - #{error.message}"
        @compile_errors_list << message
        @logger.error("Compilation error in #{filename}: #{error.message}")
        if error.respond_to?(:location) && error.location
          @logger.error("  at line #{error.location.lineno} in #{error.location.filename}")
        end
        log_backtrace(error)
      end

      def handle_unexpected_error(filename, error)
        message = "#{filename}: #{error.message}"
        @compile_errors_list << message
        @logger.error("AST Renderer Error in #{filename}: #{error.message}")
        log_backtrace(error)
      end

      def log_backtrace(error)
        return unless @config.dig('ast', 'debug')

        @logger.debug('Backtrace:')
        error.backtrace.first(10).each { |line| @logger.debug("  #{line}") }
      end

      def record_error(message)
        @compile_errors_list << message
        @logger.error("AST Renderer Error: #{message}")
      end
    end
  end
end
