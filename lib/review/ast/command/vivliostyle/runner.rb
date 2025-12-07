# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'json'
require 'fileutils'
require 'review/i18n'
require 'review/loggable'

module ReVIEW
  module AST
    module Command
      module Vivliostyle
        # Runner handles Vivliostyle config generation and CLI execution
        class Runner
          include Loggable

          def initialize(context:)
            @context = context
            @logger = ReVIEW.logger
          end

          def generate_config
            author_names = join_with_separator(config.names_of('aut'), I18n.t('names_splitter'))

            config_data = {
              'title' => config.name_of('booktitle'),
              'author' => author_names,
              'language' => config['language'],
              'size' => config['vivliostylemaker']['size'] || 'JIS-B5',
              'entry' => @context.entry_files,
              'output' => "#{config['bookname']}.pdf",
              'workspaceDir' => '.vivliostyle'
            }

            # Add theme if specified
            theme = config['vivliostylemaker']['theme']
            config_data['theme'] = theme if theme

            config_path = @context.output_path('vivliostyle.config.json')
            File.write(config_path, JSON.pretty_generate(config_data))
            debug('Generated vivliostyle.config.json')
          end

          def run_build
            cmd = build_vivliostyle_command

            debug("Running: #{cmd.join(' ')}")

            Dir.chdir(@context.build_path) do
              result = system(*cmd)
              unless result
                error! 'Vivliostyle build failed. Check the output above for details.'
              end
            end
          end

          def finalize_output
            bookname = config['bookname']
            src_pdf = @context.output_path("#{bookname}.pdf")
            dest_pdf = File.join(@context.basedir, "#{bookname}.pdf")

            if File.exist?(src_pdf)
              FileUtils.cp(src_pdf, dest_pdf)
              debug("Output: #{dest_pdf}")
            else
              error! "PDF file was not generated: #{src_pdf}"
            end
          end

          private

          def config
            @context.config
          end

          def build_vivliostyle_command
            cmd = if config['vivliostylemaker']['use_npx']
                    # Use npx (ignores vivliostyle_path)
                    ['npx', '@vivliostyle/cli', 'build', '-c', 'vivliostyle.config.json']
                  else
                    # Use vivliostyle_path
                    vivliostyle_path = resolve_vivliostyle_path
                    [vivliostyle_path, 'build', '-c', 'vivliostyle.config.json']
                  end

            # Add press-ready option if specified
            if config['vivliostylemaker']['press_ready']
              cmd << '--press-ready'
            end

            cmd
          end

          def resolve_vivliostyle_path
            vivliostyle_path = config['vivliostylemaker']['vivliostyle_path'] || 'vivliostyle'

            # Check if vivliostyle exists
            if system("which #{vivliostyle_path} > /dev/null 2>&1") ||
               File.exist?(File.join(@context.basedir, vivliostyle_path))
              return vivliostyle_path
            end

            # Try to find in node_modules
            node_path = File.join(@context.basedir, 'node_modules', '.bin', 'vivliostyle')
            if File.exist?(node_path)
              return node_path
            end

            error! 'Vivliostyle CLI not found. Please install with: npm install @vivliostyle/cli'
          end

          def join_with_separator(value, sep)
            if value.is_a?(Array)
              value.join(sep)
            else
              value.to_s
            end
          end
        end
      end
    end
  end
end
