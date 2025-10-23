# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/compiler'
require 'review/idgxmlbuilder'
require 'review/renderer/idgxml_renderer'
require 'review/ast'
require 'review/ast/compiler'
require 'review/ast/book_indexer'
require 'review/book'
require 'review/configure'
require 'review/i18n'
require 'stringio'
require 'yaml'

module ReVIEW
  # IDGXMLConverter converts *.re files to IDGXML using both IDGXMLBuilder and IdgxmlRenderer
  # for comparison purposes.
  class IDGXMLConverter
    # Convert a Re:VIEW source string to IDGXML using IDGXMLBuilder
    #
    # @param source [String] Re:VIEW source content
    # @param chapter [ReVIEW::Book::Chapter, nil] Chapter context (optional)
    # @return [String] Generated IDGXML
    def convert_with_builder(source, chapter: nil)
      # Create a temporary book/chapter if not provided
      unless chapter
        book = create_temporary_book
        chapter = create_temporary_chapter(book, source)
      end

      # Create IDGXMLBuilder
      builder = IDGXMLBuilder.new
      compiler = Compiler.new(builder)
      builder.bind(compiler, chapter, Location.new('test', nil))

      # Compile the chapter
      compiler.compile(chapter)

      # Get raw result and normalize it for comparison
      result = builder.raw_result
      normalize_builder_output(result)
    end

    # Convert a Re:VIEW source string to IDGXML using IdgxmlRenderer
    #
    # @param source [String] Re:VIEW source content
    # @param chapter [ReVIEW::Book::Chapter, nil] Chapter context (optional)
    # @return [String] Generated IDGXML
    def convert_with_renderer(source, chapter: nil)
      # Create a temporary book/chapter if not provided
      unless chapter
        book = create_temporary_book
        chapter = create_temporary_chapter(book, source)
      end

      # Parse to AST
      ast_compiler = ReVIEW::AST::Compiler.for_chapter(chapter)
      ast = ast_compiler.compile_to_ast(chapter)

      # Render with IdgxmlRenderer
      renderer = Renderer::IdgxmlRenderer.new(chapter)

      # Get the full rendered output
      result = renderer.render(ast)
      normalize_renderer_output(result)
    end

    # Convert a chapter from a book project to IDGXML using both builder and renderer
    #
    # @param book_dir [String] Path to book project directory
    # @param chapter_name [String] Chapter filename (e.g., 'ch01.re' or 'ch01')
    # @return [Hash] Hash with :builder and :renderer keys containing IDGXML output
    def convert_chapter_with_book_context(book_dir, chapter_name)
      # Ensure book_dir is absolute
      book_dir = File.expand_path(book_dir)

      # Load book configuration
      book = load_book(book_dir)

      # Find chapter by name (with or without .re extension)
      chapter_name = chapter_name.sub(/\.re$/, '')
      chapter = book.chapters.find { |ch| ch.name == chapter_name }

      raise "Chapter '#{chapter_name}' not found in book at #{book_dir}" unless chapter

      # Convert with both builder and renderer
      builder_idgxml = convert_with_builder(nil, chapter: chapter)
      renderer_idgxml = convert_with_renderer(nil, chapter: chapter)

      {
        builder: builder_idgxml,
        renderer: renderer_idgxml
      }
    end

    private

    # Create a temporary book for testing
    def create_temporary_book
      book_config = Configure.values

      # Set default IDGXML configuration
      book_config['builder'] = 'idgxml'
      book_config['language'] = 'ja'
      book_config['tableopt'] = '10' # Default table column width

      # Initialize I18n
      I18n.setup(book_config['language'])

      Book::Base.new('.', config: book_config)
    end

    # Create a temporary chapter for testing
    def create_temporary_chapter(book, source = '')
      # Create a StringIO with the source content
      io = StringIO.new(source)
      Book::Chapter.new(book, 1, 'test', 'test.re', io)
    end

    # Load a book from a directory
    def load_book(book_dir)
      # Change to book directory to load configuration
      Dir.chdir(book_dir) do
        # Load book configuration from config.yml
        book_config = Configure.values
        config_file = File.join(book_dir, 'config.yml')
        if File.exist?(config_file)
          yaml_config = YAML.load_file(config_file, permitted_classes: [Date, Time, Symbol])
          book_config.merge!(yaml_config) if yaml_config
        end

        # Set default IDGXML configuration
        book_config['builder'] ||= 'idgxml'
        book_config['language'] ||= 'ja'
        book_config['tableopt'] ||= '10'

        # Initialize I18n
        I18n.setup(book_config['language'])

        # Create book instance
        book = Book::Base.new(book_dir, config: book_config)

        # Initialize book-wide indexes early for cross-chapter references
        ReVIEW::AST::BookIndexer.build(book)

        book
      end
    end

    # Normalize builder output for comparison
    # Builder output may have different formatting than renderer
    def normalize_builder_output(output)
      # Remove XML declaration and doc wrapper tags (same as renderer)
      output = output.sub(/\A<\?xml[^>]+\?>\s*/, '').sub(/\A<doc[^>]*>/, '').sub(%r{</doc>\s*\z}, '')

      # Remove leading/trailing whitespace
      output.strip
    end

    # Normalize renderer output for comparison
    # Renderer wraps output in XML declaration and doc tags
    def normalize_renderer_output(output)
      # Remove XML declaration and doc wrapper tags
      output = output.sub(/\A<\?xml[^>]+\?><doc[^>]*>/, '').sub(%r{</doc>\s*\z}, '')

      # Remove leading/trailing whitespace
      output.strip
    end
  end
end
