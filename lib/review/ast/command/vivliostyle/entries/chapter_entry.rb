# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/ast'
require 'review/renderer/html_renderer'
require_relative '../entry'

module ReVIEW
  module AST
    module Command
      module Vivliostyle
        module Entries
          # ChapterEntry generates the chapter HTML using AST Compiler and HtmlRenderer
          class ChapterEntry < Entry
            attr_reader :chapter

            def initialize(context:, chapter:)
              super(context: context)
              @chapter = chapter
              @filename = "#{chapter.name}.html"
              @title = chapter.title
              @compile_error = false
            end

            def compile_error?
              @compile_error
            end

            def generate
              id = File.basename(@chapter.path, '.*')

              if @context.buildonly && !@context.buildonly.include?(id)
                warn "skip #{id}.re"
                return
              end

              begin
                write
                debug("Compiled #{@chapter.path} -> #{@filename}")
              rescue StandardError => e
                @compile_error = true
                error "compile error in #{@chapter.path} (#{e.class})"
                error e.message
                puts e.backtrace.first(10).join("\n") if @context.debug?
              end
            end

            def render
              # Compile chapter to AST
              compiler = ReVIEW::AST::Compiler.for_chapter(@chapter)
              ast_root = compiler.compile_to_ast(@chapter)

              # Render to HTML
              renderer = ReVIEW::Renderer::HtmlRenderer.new(@chapter)
              renderer.visit(ast_root)
            end
          end
        end
      end
    end
  end
end
