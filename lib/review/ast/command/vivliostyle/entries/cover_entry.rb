# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'fileutils'
require 'review/ast'
require 'review/renderer/html_renderer'
require 'review/book/chapter'
require_relative '../entry'

module ReVIEW
  module AST
    module Command
      module Vivliostyle
        module Entries
          # CoverEntry generates the cover page HTML from various source types
          class CoverEntry < Entry
            SUPPORTED_IMAGE_EXTS = %w[.png .jpg .jpeg .gif .svg].freeze
            SUPPORTED_HTML_EXTS = %w[.html .htm .xhtml].freeze
            SUPPORTED_REVIEW_EXTS = %w[.re .md].freeze

            attr_reader :source

            def initialize(context:, source:)
              super(context: context)
              @source = source
              @filename = 'cover.html'
              @title = config.name_of('booktitle')
              @source_type = detect_source_type
            end

            def generate
              case @source_type
              when :image
                generate_image_cover
              when :html
                generate_html_cover
              when :review
                generate_review_cover
              when :coverimage
                generate_coverimage
              else
                warn "Unsupported cover source: #{@source}"
              end
            end

            def render
              # render is called by generate_review_cover
              raise NotImplementedError, 'CoverEntry#render should not be called directly'
            end

            private

            def detect_source_type
              return :coverimage if @source.start_with?('coverimage:')

              ext = File.extname(@source).downcase
              if SUPPORTED_IMAGE_EXTS.include?(ext)
                :image
              elsif SUPPORTED_HTML_EXTS.include?(ext)
                :html
              elsif SUPPORTED_REVIEW_EXTS.include?(ext)
                :review
              else
                :unknown
              end
            end

            # Generate cover from image file in coverfile
            def generate_image_cover
              src_path = @context.source_path(@source)
              unless File.exist?(src_path)
                warn "Cover file not found: #{@source}"
                return
              end

              render_image_cover(src_path, File.basename(@source))
            end

            # Generate cover from coverimage (relative to imagedir)
            def generate_coverimage
              image_name = @source.sub(/\Acoverimage:/, '')
              src_path = @context.source_path(File.join(config['imagedir'], image_name))
              unless File.exist?(src_path)
                warn "Cover image not found: #{image_name}"
                return
              end

              render_image_cover(src_path, image_name)
            end

            def render_image_cover(src_path, original_filename)
              # Copy cover image to build directory
              dest_filename = "cover#{File.extname(original_filename)}"
              FileUtils.cp(src_path, @context.output_path(dest_filename))

              # Generate cover HTML
              body = <<~HTML
                <div class="cover">
                  <img src="#{h(dest_filename)}" alt="#{h(@title)}" class="cover-image" />
                </div>
              HTML
              html = layout_wrapper.wrap(body, title: @title)
              layout_wrapper.write_html(@filename, html)
              @context.add_entry_file(@filename)
              debug("Generated cover page from image: #{original_filename}")
            end

            def generate_html_cover
              src_path = @context.source_path(@source)
              unless File.exist?(src_path)
                warn "Cover file not found: #{@source}"
                return
              end

              content = File.read(src_path)

              # If it's a fragment (no DOCTYPE), wrap with layout
              html = if content.include?('<!DOCTYPE') || content.include?('<html')
                       # Full HTML document - use as-is
                       content
                     else
                       # HTML fragment - wrap with layout
                       layout_wrapper.wrap(content, title: @title)
                     end

              layout_wrapper.write_html(@filename, html)
              @context.add_entry_file(@filename)
              debug("Copied cover page: #{@source}")
            end

            def generate_review_cover
              cover_path = @context.source_path(@source)
              unless File.exist?(cover_path)
                warn "Cover file not found: #{@source}"
                return
              end

              begin
                # Create a temporary chapter for the cover
                cover_chapter = ReVIEW::Book::Chapter.new(
                  book, nil, '-', cover_path, nil
                )

                # Compile to AST
                compiler = ReVIEW::AST::Compiler.for_chapter(cover_chapter)
                ast_root = compiler.compile_to_ast(cover_chapter)

                # Render to HTML
                renderer = ReVIEW::Renderer::HtmlRenderer.new(cover_chapter)
                html_body = renderer.visit(ast_root)

                # Wrap with layout
                body = %Q(<div class="cover">#{html_body}</div>)
                html = layout_wrapper.wrap(body, title: @title)

                layout_wrapper.write_html(@filename, html)
                @context.add_entry_file(@filename)
                debug("Compiled cover page: #{@source}")
              rescue StandardError => e
                warn "Failed to compile cover file: #{e.message}"
              end
            end
          end
        end
      end
    end
  end
end
