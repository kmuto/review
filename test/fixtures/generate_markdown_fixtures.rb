#!/usr/bin/env ruby
# frozen_string_literal: true

# Script to generate Markdown fixtures from sample Re:VIEW files
# Run this script to update fixtures when MarkdownRenderer implementation changes
#
# Usage:
#   bundle exec ruby test/fixtures/generate_markdown_fixtures.rb

require_relative '../../lib/review/ast'
require_relative '../../lib/review/ast/compiler'
require_relative '../../lib/review/renderer/markdown_renderer'
require_relative '../../lib/review/configure'
require_relative '../../lib/review/book'
require_relative '../../lib/review/book/chapter'

def generate_fixture(chapter, output_file)
  puts "Generating #{output_file} from #{chapter.path}..."

  begin
    ast = ReVIEW::AST::Compiler.new.compile_to_ast(chapter)
    markdown = ReVIEW::Renderer::MarkdownRenderer.new(chapter).render(ast)

    # Write output file
    File.write(output_file, markdown, encoding: 'UTF-8')
    puts "  ✓ Successfully generated #{output_file}"
  rescue StandardError => e
    puts "  ✗ Error generating #{output_file}: #{e.message}"
    puts "    #{e.backtrace.first}"
  end
end

def generate_fixtures_for_book(book_dir, fixture_dir)
  puts "\nGenerating fixtures for #{book_dir}..."

  begin
    # Setup configuration
    config = ReVIEW::Configure.values
    config['secnolevel'] = 2
    config['language'] = 'ja'
    ReVIEW::I18n.setup(config['language'])

    # Load book structure from catalog.yml
    book = ReVIEW::Book::Base.load(book_dir)
    book.config = config

    # Generate indexes for cross-references
    book.generate_indexes

    # Get all chapters from the book (includes predef, chapters, appendix, postdef)
    chapters = book.chapters

    puts "Found #{chapters.size} chapters in book structure"

    chapters.each do |chapter|
      basename = chapter.id
      output_file = File.join(fixture_dir, "#{basename}.md")
      generate_fixture(chapter, output_file)
    end
  rescue StandardError => e
    puts "  ✗ Error loading book structure: #{e.message}"
    puts "    #{e.backtrace.first(3).join("\n    ")}"
  end
end

# Main execution
puts '=' * 60
puts 'Markdown Fixture Generator'
puts '=' * 60

# Generate fixtures for syntax-book
syntax_book_dir = File.join(__dir__, '../../samples/syntax-book')
syntax_fixture_dir = File.join(__dir__, 'markdown/syntax-book')
generate_fixtures_for_book(syntax_book_dir, syntax_fixture_dir)

# Generate fixtures for debug-book
debug_book_dir = File.join(__dir__, '../../samples/debug-book')
debug_fixture_dir = File.join(__dir__, 'markdown/debug-book')
generate_fixtures_for_book(debug_book_dir, debug_fixture_dir)

puts "\n" + ('=' * 60)
puts 'Fixture generation complete!'
puts '=' * 60
