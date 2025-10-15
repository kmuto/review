# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'optparse'
require 'stringio'
require 'review/book'
require 'review/ast/compiler'
require 'review/version'
require 'review/configure'
require 'review/loggable'
require 'review/logger'

module ReVIEW
  module Command
    # Compile - AST-based compilation command
    #
    # This command compiles Re:VIEW source files using AST and Renderer directly,
    # without using traditional Builder classes.
    class Compile
      include ReVIEW::Loggable

      class CompileError < StandardError; end
      class FileNotFoundError < CompileError; end
      class UnsupportedFormatError < CompileError; end
      class MissingTargetError < CompileError; end

      # Exit status codes
      EXIT_SUCCESS = 0
      EXIT_COMPILE_ERROR = 1
      EXIT_UNEXPECTED_ERROR = 2

      attr_reader :options, :logger

      def initialize
        @options = {
          target: nil,
          check_only: false,
          verbose: false,
          output_file: nil,
          config_file: nil
        }
        @version_requested = false
        @help_requested = false

        # Initialize logger for Loggable
        @logger = ReVIEW.logger
      end

      def run(args)
        parse_arguments(args)

        # --version or --help already handled
        return EXIT_SUCCESS if @version_requested || @help_requested

        validate_options
        compile
        EXIT_SUCCESS
      rescue CompileError => e
        error_handler.handle(e)
        EXIT_COMPILE_ERROR
      rescue StandardError => e
        error_handler.handle_unexpected(e)
        EXIT_UNEXPECTED_ERROR
      end

      private

      def parse_arguments(args)
        parser = create_option_parser
        parser.parse!(args)

        if args.empty? && !@help_requested && !@version_requested && !@options[:check_only]
          raise CompileError, 'No input file specified. Use -h for help.'
        end

        @input_file = args[0] unless args.empty?
      end

      def create_option_parser
        OptionParser.new do |opts|
          opts.banner = 'Usage: review-ast-compile --target FORMAT <file>'
          opts.version = ReVIEW::VERSION

          opts.on('-t', '--target FORMAT', 'Output format (html, latex) [required unless --check]') do |fmt|
            @options[:target] = fmt
          end

          opts.on('-o', '--output-file FILE', 'Output file (default: stdout)') do |file|
            @options[:output_file] = file
          end

          opts.on('--config FILE', '--yaml FILE', 'Configuration file (config.yml)') do |file|
            @options[:config_file] = file
          end

          opts.on('-c', '--check', 'Check only, no output') do
            @options[:check_only] = true
          end

          opts.on('-v', '--verbose', 'Verbose output') do
            @options[:verbose] = true
          end

          opts.on_tail('--version', 'Show version') do
            puts opts.version
            @version_requested = true
          end

          opts.on_tail('-h', '--help', 'Show this help') do
            puts opts
            @help_requested = true
          end
        end
      end

      def validate_options
        # --check mode doesn't require --target
        return if @options[:check_only]

        # --target is required for output generation
        if @options[:target].nil?
          raise MissingTargetError, '--target option is required (use --target html or --target latex)'
        end
      end

      def compile
        validate_input_file

        content = load_file(@input_file)
        chapter = create_chapter(content)
        ast = generate_ast(chapter)

        if @options[:check_only]
          log("Syntax check passed: #{@input_file}")
        else
          output = render(ast, chapter)
          output_content(output)
        end
      end

      def validate_input_file
        unless @input_file
          raise CompileError, 'No input file specified'
        end

        unless File.exist?(@input_file)
          raise FileNotFoundError, "Input file not found: #{@input_file}"
        end

        unless File.readable?(@input_file)
          raise CompileError, "Cannot read file: #{@input_file}"
        end
      end

      def load_file(path)
        log("Loading: #{path}")
        File.read(path)
      rescue StandardError => e
        raise CompileError, "Failed to read file: #{e.message}"
      end

      def create_chapter(content)
        # Load configuration if specified
        config = load_configuration

        # Setup I18n with config language
        require 'review/i18n'
        I18n.setup(config['language'] || 'ja')

        # Create book with configuration
        book_basedir = File.dirname(@input_file)
        book = ReVIEW::Book::Base.new(book_basedir, config: config)
        basename = File.basename(@input_file, '.*')

        # Try to find the correct chapter number from book catalog
        chapter_number = find_chapter_number(book, basename)

        # If chapter number not found, try to extract from filename (e.g., ch03.re -> 3)
        if chapter_number.nil?
          chapter_number = extract_chapter_number_from_filename(basename)
        end

        # Final fallback to 1 if all else fails
        chapter_number ||= 1

        chapter = ReVIEW::Book::Chapter.new(
          book,
          chapter_number,
          basename,
          @input_file,
          StringIO.new(content)
        )

        # Initialize book-wide indexes early for cross-chapter references
        require 'review/ast/indexer'
        ReVIEW::AST::Indexer.build_book_indexes(book)

        chapter
      end

      def find_chapter_number(book, basename)
        # Try to load catalog and find chapter number
        return nil unless book

        # Look for catalog.yml in the book directory
        catalog_file = File.join(book.basedir, 'catalog.yml')
        return nil unless File.exist?(catalog_file)

        begin
          require 'yaml'
          catalog = YAML.load_file(catalog_file)

          # Search in CHAPS section for the chapter filename
          if catalog['CHAPS']
            catalog['CHAPS'].each_with_index do |chapter_file, index|
              # Remove extension and compare basename
              catalog_basename = File.basename(chapter_file, '.*')
              return index + 1 if catalog_basename == basename
            end
          end
        rescue StandardError => e
          log("Warning: Could not parse catalog.yml: #{e.message}")
        end

        nil
      end

      def extract_chapter_number_from_filename(basename)
        # Try to extract chapter number from common filename patterns
        case basename
        when /^ch(?:ap)?(\d+)$/i # ch01, ch1, chap01, chap1, etc.
          $1.to_i
        when /^chapter(\d+)$/i # rubocop:disable Lint/DuplicateBranch -- chapter01, chapter1, etc.
          $1.to_i
        when /^(\d+)$/ # rubocop:disable Lint/DuplicateBranch -- 01, 1, etc.
          $1.to_i
        else
          log("Warning: Could not extract chapter number from filename '#{basename}', using fallback")
          nil
        end
      end

      def generate_ast(chapter)
        log('Generating AST...')
        compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
        compiler.compile_to_ast(chapter)
      rescue StandardError => e
        raise CompileError, "AST generation failed: #{e.message}"
      end

      def render(ast, chapter)
        log("Rendering to #{@options[:target]}...")

        renderer_class = load_renderer(@options[:target])
        renderer = renderer_class.new(chapter)
        renderer.render(ast)
      rescue StandardError => e
        raise CompileError, "Rendering failed: #{e.message}"
      end

      def load_configuration
        # Determine config file to load
        config_file = @options[:config_file]

        # If no config file specified, try to find default config.yml in the same directory as input file
        if config_file.nil?
          default_config = File.join(File.dirname(@input_file), 'config.yml')
          config_file = default_config if File.exist?(default_config)
        end

        # Load configuration using ReVIEW::Configure
        if config_file && File.exist?(config_file)
          log("Loading configuration: #{config_file}")
          begin
            config = ReVIEW::Configure.create(
              maker: 'ast-compile',
              yamlfile: config_file
            )
          rescue StandardError => e
            raise CompileError, "Failed to load configuration: #{e.message}"
          end
        else
          if @options[:config_file]
            raise CompileError, "Configuration file not found: #{@options[:config_file]}"
          end

          # Use default configuration
          log('Using default configuration')
          config = ReVIEW::Configure.values
        end

        config
      end

      def load_renderer(format)
        case format
        when 'html'
          require 'review/renderer/html_renderer'
          ReVIEW::Renderer::HtmlRenderer
        when 'latex'
          require 'review/renderer/latex_renderer'
          ReVIEW::Renderer::LatexRenderer
        else
          raise UnsupportedFormatError, "Unsupported format: #{format}"
        end
      end

      def output_content(content)
        if @options[:output_file]
          # Output to file
          log("Writing to: #{@options[:output_file]}")
          File.write(@options[:output_file], content)
          puts "Successfully generated: #{@options[:output_file]}"
        else
          # Output to stdout
          log('Writing to: stdout')
          print content
        end
      rescue StandardError => e
        raise CompileError, "Failed to write output: #{e.message}"
      end

      def generate_output_filename
        basename = File.basename(@input_file, '.*')
        ext = output_extension(@options[:target])
        "#{basename}#{ext}"
      end

      def output_extension(format)
        case format
        when 'html' then '.html'
        when 'latex' then '.tex'
        end
      end

      def log(message)
        puts message if @options[:verbose]
      end

      def error_handler
        @error_handler ||= ErrorHandler.new(@options[:verbose], logger: @logger)
      end

      # Internal class for error handling
      class ErrorHandler
        include ReVIEW::Loggable

        def initialize(verbose, logger:)
          @verbose = verbose
          @logger = logger
        end

        def handle(err)
          error err.message.to_s
          case err
          when FileNotFoundError
            error 'Please check the file path and try again.'
          when UnsupportedFormatError
            error 'Supported formats: html, latex'
          when MissingTargetError
            error 'Example: review-ast-compile --target html chapter1.re'
          end

          if @verbose && err.backtrace
            error "\nBacktrace:"
            error err.backtrace.take(10).join("\n")
          end
        end

        def handle_unexpected(err)
          error "Unexpected error occurred: #{err.class}"
          error err.message

          if @verbose && err.backtrace
            error "\nBacktrace:"
            error err.backtrace.join("\n")
          else
            error "\nUse --verbose for more details."
          end
        end
      end
    end
  end
end
