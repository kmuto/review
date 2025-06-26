# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast/indexer'
require 'review/book'
require 'review/book/chapter'
require 'review/ast/compiler'

class TestASTIndexerPure < Test::Unit::TestCase
  def setup
    @book = ReVIEW::Book::Base.new
    @config = ReVIEW::Configure.values
    @config['secnolevel'] = 2
    @config['language'] = 'ja'
    @book.config = @config

    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)

    @chapter = ReVIEW::Book::Chapter.new(@book, 1, 'test_chapter', 'test_chapter.re', StringIO.new)
    ReVIEW::I18n.setup(@config['language'])
  end

  def test_basic_index_building
    source = <<~EOS
      = Chapter Title

      Basic paragraph with text.

      //list[sample-code][Sample Code Caption][ruby]{
      puts "hello world"
      //}

      //table[sample-table][Sample Table Caption]{
      Header 1	Header 2
      ------------
      Cell 1	Cell 2
      //}

      //image[sample-image][Sample Image Caption]

      Text with @<fn>{footnote1} and @<eq>{equation1}.
    EOS

    @chapter.content = source

    # Build AST without builder rendering
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Build indexes using AST::Indexer
    indexer = ReVIEW::AST::Indexer.new(@chapter)
    indexer.build_indexes(ast_root)

    # Verify list index
    assert_equal 1, indexer.list_index.size
    list_item = indexer.list_index['sample-code']
    assert_not_nil(list_item)
    assert_equal 1, list_item.number
    assert_equal 'sample-code', list_item.id

    # Verify table index
    assert_equal 1, indexer.table_index.size
    table_item = indexer.table_index['sample-table']
    assert_not_nil(table_item)
    assert_equal 1, table_item.number
    assert_equal 'sample-table', table_item.id
    assert_equal 'Sample Table Caption', table_item.caption

    # Verify image index
    assert_equal 1, indexer.image_index.size
    image_item = indexer.image_index['sample-image']
    assert_not_nil(image_item)
    assert_equal 1, image_item.number
    assert_equal 'sample-image', image_item.id
    assert_equal 'Sample Image Caption', image_item.caption

    # Verify footnote index
    assert_equal 1, indexer.footnote_index.size
    footnote_item = indexer.footnote_index['footnote1']
    assert_not_nil(footnote_item)
    assert_equal 1, footnote_item.number
    assert_equal 'footnote1', footnote_item.id

    # Verify equation index
    assert_equal 1, indexer.equation_index.size
    equation_item = indexer.equation_index['equation1']
    assert_not_nil(equation_item)
    assert_equal 1, equation_item.number
    assert_equal 'equation1', equation_item.id
  end

  def test_headline_index_building
    source = <<~EOS
      = Chapter Title

      =={sec1} Section 1

      Basic text.

      =={sec2} Section 2

      More text.

      ==={subsec21} Subsection 2.1

      Subsection content.
    EOS

    @chapter.content = source

    # Build AST without builder rendering
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Build indexes using AST::Indexer
    indexer = ReVIEW::AST::Indexer.new(@chapter)
    indexer.build_indexes(ast_root)

    # Verify headline index structure
    assert_not_nil(indexer.headline_index)
    assert indexer.headline_index.size >= 2

    # Check level 2 headings
    sec1_item = indexer.headline_index['sec1']
    assert_not_nil(sec1_item)
    assert_equal 'sec1', sec1_item.id
    assert_equal [1], sec1_item.number

    sec2_item = indexer.headline_index['sec2']
    assert_not_nil(sec2_item)
    assert_equal 'sec2', sec2_item.id
    assert_equal [2], sec2_item.number

    # Check level 3 headings
    subsec_item = indexer.headline_index['sec2|subsec21']
    assert_not_nil(subsec_item)
    assert_equal 'sec2|subsec21', subsec_item.id
    assert_equal [2, 1], subsec_item.number
  end

  def test_minicolumn_index_building
    source = <<~EOS
      = Chapter Title

      //note[Note Caption]{
      This is a note with @<fn>{note-footnote}.
      //}

      //memo[Memo Caption]{
      This is a memo with @<bib>{bibitem1}.
      //}
    EOS

    @chapter.content = source

    # Build AST without builder rendering
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Build indexes using AST::Indexer
    indexer = ReVIEW::AST::Indexer.new(@chapter)
    indexer.build_indexes(ast_root)

    # Verify inline elements within minicolumns are indexed
    assert_equal 1, indexer.footnote_index.size
    footnote_item = indexer.footnote_index['note-footnote']
    assert_not_nil(footnote_item)
    assert_equal 'note-footnote', footnote_item.id

    assert_equal 1, indexer.bibpaper_index.size
    bib_item = indexer.bibpaper_index['bibitem1']
    assert_not_nil(bib_item)
    assert_equal 'bibitem1', bib_item.id
  end

  def test_table_inline_elements
    source = <<~EOS
      = Chapter Title

      //table[inline-table][Table with inline elements]{
      Header @<b>{Bold}	@<i>{Italic} Header
      ------------
      Cell with @<fn>{table-fn}	@<eq>{table-eq}
      //}
    EOS

    @chapter.content = source

    # Build AST without builder rendering
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Build indexes using AST::Indexer
    indexer = ReVIEW::AST::Indexer.new(@chapter)
    indexer.build_indexes(ast_root)

    # Verify table index
    assert_equal 1, indexer.table_index.size
    table_item = indexer.table_index['inline-table']
    assert_not_nil(table_item)

    # Verify inline elements in table content are indexed
    assert_equal 1, indexer.footnote_index.size
    footnote_item = indexer.footnote_index['table-fn']
    assert_not_nil(footnote_item)
    assert_equal 'table-fn', footnote_item.id

    assert_equal 1, indexer.equation_index.size
    equation_item = indexer.equation_index['table-eq']
    assert_not_nil(equation_item)
    assert_equal 'table-eq', equation_item.id
  end

  def test_code_block_inline_elements
    source = <<~EOS
      = Chapter Title

      //list[code-with-inline][Code with inline elements][ruby]{
      puts @<b>{bold code}
      # Comment with @<fn>{code-fn}
      //}
    EOS

    @chapter.content = source

    # Build AST without builder rendering
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Build indexes using AST::Indexer
    indexer = ReVIEW::AST::Indexer.new(@chapter)
    indexer.build_indexes(ast_root)

    # Verify code block index
    assert_equal 1, indexer.list_index.size
    list_item = indexer.list_index['code-with-inline']
    assert_not_nil(list_item)

    # Verify inline elements in code block are indexed
    assert_equal 1, indexer.footnote_index.size
    footnote_item = indexer.footnote_index['code-fn']
    assert_not_nil(footnote_item)
    assert_equal 'code-fn', footnote_item.id
  end

  def test_empty_ast
    # Test with empty AST
    test_chapter = ReVIEW::Book::Chapter.new(@book, 1, 'empty_test', 'empty_test.re', StringIO.new)
    indexer = ReVIEW::AST::Indexer.new(test_chapter)
    result = indexer.build_indexes(nil)

    assert_equal indexer, result
    assert_equal 0, indexer.list_index.size
    assert_equal 0, indexer.table_index.size
    assert_equal 0, indexer.image_index.size
    assert_equal 0, indexer.footnote_index.size
    assert_equal 0, indexer.equation_index.size
  end

  def test_indexes_method
    source = <<~EOS
      = Chapter Title

      //list[sample][Sample]{
      code
      //}
    EOS

    @chapter.content = source

    # Build AST without builder rendering
    ast_compiler = ReVIEW::AST::Compiler.new
    ast_root = ast_compiler.compile_to_ast(@chapter)

    # Build indexes using AST::Indexer
    indexer = ReVIEW::AST::Indexer.new(@chapter)
    indexer.build_indexes(ast_root)

    # Test indexes method returns hash with all index types
    indexes = indexer.indexes
    assert_kind_of(Hash, indexes)

    expected_keys = %i[
      list table equation footnote endnote
      image icon numberless_image indepimage
      headline column bibpaper
    ]

    expected_keys.each do |key|
      assert indexes.key?(key), "Should contain #{key} index"
    end

    # Verify the list index is accessible via the hash
    assert_equal 1, indexes[:list].size
    assert_not_nil(indexes[:list]['sample'])
  end

  def test_id_validation_warnings
    source = <<~EOS
      = Chapter Title

      //list[invalid#id][Invalid ID with #]{
      code
      //}

      //table[.starts_with_dot][ID starting with dot]{
      data
      //}

      Text with @<fn>{space id} and @<eq>{id with$pecial}.
    EOS

    @chapter.content = source

    # Capture stderr to check warnings
    original_stderr = $stderr
    captured_stderr = StringIO.new
    $stderr = captured_stderr

    begin
      # Build AST without builder rendering
      ast_compiler = ReVIEW::AST::Compiler.new
      ast_root = ast_compiler.compile_to_ast(@chapter)

      # Build indexes using AST::Indexer
      indexer = ReVIEW::AST::Indexer.new(@chapter)
      indexer.build_indexes(ast_root)

      # Check that warnings were output
      warnings = captured_stderr.string
      assert_include(warnings, 'deprecated ID: `#` in `invalid#id`')
      assert_include(warnings, 'deprecated ID: `.starts_with_dot` begins from `.`')
      assert_include(warnings, 'deprecated ID: ` ` in `space id`')
      assert_include(warnings, 'deprecated ID: `$` in `id with$pecial`')
    ensure
      $stderr = original_stderr
    end
  end
end
