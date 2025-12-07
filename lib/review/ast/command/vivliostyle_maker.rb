# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/i18n'
require 'review/book'
require 'review/configure'
require 'review/version'
require 'review/makerhelper'
require 'review/loggable'
require 'review/call_hook'

require 'review/ast'
require 'review/ast/book_indexer'

require_relative 'vivliostyle/cli/parser'
require_relative 'vivliostyle/build_context'
require_relative 'vivliostyle/asset_manager'
require_relative 'vivliostyle/entry'
require_relative 'vivliostyle/entries/cover_entry'
require_relative 'vivliostyle/entries/titlepage_entry'
require_relative 'vivliostyle/entries/toc_entry'
require_relative 'vivliostyle/entries/part_entry'
require_relative 'vivliostyle/entries/chapter_entry'
require_relative 'vivliostyle/entries/colophon_entry'
require_relative 'vivliostyle/runner'

module ReVIEW
  module AST
    module Command
      # VivliostyleMaker - PDF generator using Vivliostyle CLI with AST Renderer
      class VivliostyleMaker
        include MakerHelper
        include Loggable
        include ReVIEW::CallHook

        attr_accessor :config, :basedir

        def initialize
          @basedir = nil
          @logger = ReVIEW.logger
        end

        def self.execute(*args)
          new.execute(*args)
        end

        def execute(*args)
          options = Vivliostyle::CLI::Parser.parse(args)
          error! "#{options.yamlfile} not found." unless File.exist?(options.yamlfile)

          begin
            @config = ReVIEW::Configure.create(
              maker: 'vivliostylemaker',
              yamlfile: options.yamlfile,
              config: options.cmd_config
            )
          rescue ReVIEW::ConfigError => e
            error! e.message
          end

          update_log_level
          I18n.setup(@config['language'])

          begin
            generate_pdf(options.yamlfile, buildonly: options.buildonly)
          rescue ApplicationError => e
            raise if @config['debug']

            error! e.message
          end
        end

        private

        def update_log_level
          if @config['debug']
            if @logger.ttylogger?
              ReVIEW.logger = nil
              @logger = ReVIEW.logger(level: 'debug')
            else
              @logger.level = Logger::DEBUG
            end
          elsif !@logger.ttylogger?
            @logger.level = Logger::INFO
          end
        end

        def generate_pdf(yamlfile, buildonly: nil)
          @basedir = File.absolute_path(File.dirname(yamlfile))
          bookname = @config['bookname']

          begin
            @config.check_version(ReVIEW::VERSION, exception: true)
          rescue ReVIEW::ConfigError => e
            warn e.message
          end

          debug("#{bookname}.pdf will be created with Vivliostyle.")

          # Remove old PDF
          FileUtils.rm_f("#{bookname}.pdf")

          # Create build context
          context = Vivliostyle::BuildContext.new(
            config: @config,
            basedir: @basedir,
            debug: @config['debug'],
            buildonly: buildonly
          )

          begin
            context.setup_build_directory
            debug("Created temporary directory as #{context.build_path}.")

            call_hook('hook_beforeprocess', context.build_path, base_dir: @basedir)

            # Initialize book and build indexes
            book = ReVIEW::Book::Base.new(@basedir, config: @config)
            ReVIEW::AST::BookIndexer.build(book)
            context.book = book

            # Setup assets
            asset_manager = Vivliostyle::AssetManager.new(context: context)
            asset_manager.setup_stylesheets
            asset_manager.setup_javascripts

            # Generate all entries
            compile_errors = generate_entries(context)

            call_hook('hook_afterbody', context.build_path, base_dir: @basedir)

            # Copy images
            asset_manager.copy_images
            call_hook('hook_aftercopyimage', context.build_path, base_dir: @basedir)

            # Check compile status
            check_compile_status(compile_errors)

            # Run Vivliostyle
            runner = Vivliostyle::Runner.new(context: context)
            runner.generate_config
            call_hook('hook_beforevivliostyle', context.build_path, base_dir: @basedir)
            runner.run_build
            call_hook('hook_aftervivliostyle', context.build_path, base_dir: @basedir)
            runner.finalize_output

            @logger.success("built #{bookname}.pdf")
          ensure
            context.cleanup unless @config['debug']
          end
        end

        def generate_entries(context)
          compile_errors = false

          # Frontmatter
          generate_frontmatter(context)

          # Body (parts and chapters)
          context.book.parts.each do |part|
            if part.name.present? && !part.file?
              entry = Vivliostyle::Entries::PartEntry.new(
                context: context,
                part: part
              )
              entry.generate
            end

            part.chapters.each do |chapter|
              entry = Vivliostyle::Entries::ChapterEntry.new(
                context: context,
                chapter: chapter
              )
              entry.generate
              compile_errors = true if entry.compile_error?
            end
          end

          # Backmatter
          generate_backmatter(context)

          compile_errors
        end

        def generate_frontmatter(context)
          # Cover page
          if @config['coverfile']
            entry = Vivliostyle::Entries::CoverEntry.new(
              context: context,
              source: @config['coverfile']
            )
            entry.generate
          elsif @config['coverimage']
            entry = Vivliostyle::Entries::CoverEntry.new(
              context: context,
              source: "coverimage:#{@config['coverimage']}"
            )
            entry.generate
          end

          # Title page
          if @config['titlepage']
            entry = Vivliostyle::Entries::TitlepageEntry.new(context: context)
            entry.generate
          end

          # Table of contents
          if @config['toc']
            entry = Vivliostyle::Entries::TocEntry.new(context: context)
            entry.generate
          end
        end

        def generate_backmatter(context)
          # Colophon
          if @config['colophon']
            entry = Vivliostyle::Entries::ColophonEntry.new(context: context)
            entry.generate
          end
        end

        def check_compile_status(compile_errors)
          if compile_errors
            if @config['ignore-errors']
              warn 'compile error exists, but ignored due to --ignore-errors option'
            else
              error! 'compile error, PDF file not generated.'
            end
          end
        end
      end
    end
  end
end
