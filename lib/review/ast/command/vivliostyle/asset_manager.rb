# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'fileutils'
require 'review/loggable'
require 'review/template'

module ReVIEW
  module AST
    module Command
      module Vivliostyle
        # AssetManager handles stylesheets, javascripts, and image copying
        class AssetManager
          include Loggable

          def initialize(context:)
            @context = context
            @logger = ReVIEW.logger
          end

          def setup_stylesheets
            theme = config['vivliostylemaker']['theme']

            if theme
              # Use npm theme (will be resolved by Vivliostyle CLI)
              debug("Using Vivliostyle theme: #{theme}")
            else
              # Use bundled theme-review.css
              css_src = @context.template_path('vivliostyle/theme-review.css')
              if css_src && File.exist?(css_src)
                FileUtils.cp(css_src, @context.build_path)
                @context.add_stylesheet('theme-review.css')
                debug('Using bundled theme-review.css')
              else
                warn 'theme-review.css not found, no default stylesheet applied'
              end
            end

            # Copy additional CSS files from vivliostylemaker config
            additional_css = config['vivliostylemaker']['css'] || []
            additional_css.each do |css_file|
              src = @context.source_path(css_file)
              if File.exist?(src)
                FileUtils.cp(src, @context.build_path)
                @context.add_stylesheet(File.basename(css_file))
              else
                warn "CSS file not found: #{css_file}"
              end
            end

            # Copy user stylesheets from config (exclude style.css)
            (config['stylesheet'] || []).each do |css_file|
              basename = File.basename(css_file)
              next if basename == 'style.css' # Ignore legacy style.css

              src = @context.source_path(css_file)
              if File.exist?(src)
                FileUtils.cp(src, @context.build_path)
                @context.add_stylesheet(basename)
              end
            end
          end

          def setup_javascripts
            # Always include MathJax for Vivliostyle (default math rendering, no LaTeX required)
            @context.add_javascript(%Q(<script>MathJax = { tex: { inlineMath: [['\\\\(', '\\\\)']] }, svg: { fontCache: 'global' } };</script>))
            @context.add_javascript(%Q(<script type="text/javascript" id="MathJax-script" async="true" src="https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-mml-chtml.js"></script>))
          end

          def copy_images
            imagedir = config['imagedir']
            src_dir = @context.source_path(imagedir)
            return unless File.exist?(src_dir)

            dest_dir = @context.output_path(imagedir)
            FileUtils.mkdir_p(dest_dir)

            exts = config['image_ext'] || %w[png gif jpg jpeg svg]
            copy_images_recursive(src_dir, dest_dir, exts)
          end

          private

          def config
            @context.config
          end

          def copy_images_recursive(src_dir, dest_dir, exts)
            Dir.foreach(src_dir) do |entry|
              next if entry.start_with?('.')

              src_path = File.join(src_dir, entry)
              dest_path = File.join(dest_dir, entry)

              if File.directory?(src_path)
                FileUtils.mkdir_p(dest_path)
                copy_images_recursive(src_path, dest_path, exts)
              elsif exts.any? { |ext| entry.downcase.end_with?(".#{ext}") }
                FileUtils.cp(src_path, dest_path)
              end
            end
          end
        end
      end
    end
  end
end
