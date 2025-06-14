#!/usr/bin/env ruby
# frozen_string_literal: true

# Stage 2 inline element test
require 'bundler/setup'
require 'review'
require 'review/ast_config'
require 'json'

# Set environment for Stage 2
ENV['REVIEW_AST_STAGE'] = '2'

config = ReVIEW::Configure.values
ReVIEW::I18n.setup('ja')
book = ReVIEW::Book::Base.new(config: config)

# Test inline elements in paragraphs
test_content = <<~REVIEW
= Test Inline Elements in Paragraphs

This paragraph contains @<b>{bold text}, @<i>{italic text}, and @<code>{inline code}.

Here's a paragraph with @<tt>{teletype}, @<strong>{strong emphasis}, and @<em>{emphasis}.

References: see @<chap>{intro}, @<list>{example}, @<img>{figure1}, and @<table>{data}.

Math expressions: @<m>{E = mc^2} and footnotes@<fn>{note1}.

//footnote[note1][This is a test footnote.]
REVIEW

# Create AST configuration
ast_config = ReVIEW::ASTConfig.new(config)
compiler_options = ast_config.compiler_options

# Test with JSON builder to see AST structure
json_builder = ReVIEW::JSONBuilder.new
compiler = ReVIEW::Compiler.new(json_builder, **compiler_options)

# Create mock chapter
chap = ReVIEW::Book::Chapter.new(book, nil, 'test_inline.re', 'test_inline.re')
chap.instance_variable_set(:@content, test_content)

puts '=== Testing Inline Elements in Paragraphs (Stage 2) ==='
result = compiler.compile(chap)
json = JSON.parse(result)

# Extract paragraphs and their inline elements
paragraphs = []
json['children'].each do |node|
  if node['type'] == 'ParagraphNode'
    paragraphs << node
  end
end

puts "\nFound #{paragraphs.length} paragraphs with inline elements:"

paragraphs.each_with_index do |para, i|
  puts "\n--- Paragraph #{i + 1} ---"
  puts "Children count: #{para['children'].length}"
  
  para['children'].each do |child|
    case child['type']
    when 'TextNode'
      puts "  Text: \"#{child['content']}\""
    when 'InlineNode'
      puts "  Inline: #{child['inline_type']} => \"#{child['content'] || child['children'].map { |c| c['content'] }.join}\""
    end
  end
end

# Test with HTML builder for output verification
puts "\n=== HTML Output Test ==="
html_builder = ReVIEW::HTMLBuilder.new
html_compiler = ReVIEW::Compiler.new(html_builder, **compiler_options)
html_result = html_compiler.compile(chap)

# Extract paragraph HTML
html_result.scan(%r{<p>(.+?)</p>}m).each_with_index do |match, i|
  puts "\nParagraph #{i + 1} HTML:"
  puts "  #{match[0]}"
end