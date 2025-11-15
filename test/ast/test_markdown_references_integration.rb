# frozen_string_literal: true

require_relative '../test_helper'
require 'review/ast/markdown_compiler'
require 'review/ast/reference_resolver'
require 'review/renderer/markdown_renderer'
require 'review/ast/node'
require 'review/book'
require 'review/book/chapter'
require 'review/configure'
require 'review/i18n'
require 'stringio'

return unless Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('3.1.0')

class TestMarkdownReferencesIntegration < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @config['chapter_no'] = 1
    @book = ReVIEW::Book::Base.new(config: @config)
    @compiler = ReVIEW::AST::MarkdownCompiler.new
    ReVIEW::I18n.setup(@config['language'])

    # Build book-wide indexes before compilation
    # This is necessary for cross-chapter references
    require 'review/ast/book_indexer'
    ReVIEW::AST::BookIndexer.build(@book) if @book.chapters.any?
  end

  def create_chapter(content)
    ReVIEW::Book::Chapter.new(@book, 1, 'test', 'test.md', StringIO.new(content))
  end

  def test_image_reference_resolution_and_rendering
    markdown = <<~MD
      # Test Chapter

      ![Sample Image](images/sample.png)
      {#fig-sample caption="Sample Figure"}

      図@<img>{fig-sample}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    resolver = ReVIEW::AST::ReferenceResolver.new(chapter)
    resolver.resolve_references(ast)

    renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)
    output = renderer.render(ast)

    assert_match(/図1\.1/, output, '画像参照が「図1.1」としてレンダリングされていません')
    assert_match(/href.*fig-sample/, output, '画像へのリンクが生成されていません')
  end

  def test_list_reference_resolution_and_rendering
    markdown = <<~MD
      # Test Chapter

      ```ruby {#list-sample caption="Sample Code"}
      def hello
        puts "Hello, World!"
      end
      ```

      リスト@<list>{list-sample}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    resolver = ReVIEW::AST::ReferenceResolver.new(chapter)
    resolver.resolve_references(ast)

    renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)
    output = renderer.render(ast)

    assert_match(/リスト1\.1/, output, 'リスト参照が「リスト1.1」としてレンダリングされていません')
    assert_match(/href.*list-sample/, output, 'リストへのリンクが生成されていません')
  end

  def test_table_reference_resolution_and_rendering
    markdown = <<~MD
      # Test Chapter

      | Column 1 | Column 2 |
      |----------|----------|
      | Data 1   | Data 2   |
      {#table-sample caption="Sample Table"}

      表@<table>{table-sample}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    resolver = ReVIEW::AST::ReferenceResolver.new(chapter)
    resolver.resolve_references(ast)

    renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)
    output = renderer.render(ast)

    assert_match(/表1\.1/, output, 'テーブル参照が「表1.1」としてレンダリングされていません')
    assert_match(/href.*table-sample/, output, 'テーブルへのリンクが生成されていません')
  end

  def test_multiple_references_integration
    markdown = <<~MD
      # Test Chapter

      ## 画像セクション

      ![Figure 1](images/fig1.png)
      {#fig-first caption="First Figure"}

      ![Figure 2](images/fig2.png)
      {#fig-second caption="Second Figure"}

      ## コードセクション

      ```ruby {#list-first caption="First Code"}
      puts "first"
      ```

      ```python {#list-second caption="Second Code"}
      print("second")
      ```

      ## テーブルセクション

      | A | B |
      |---|---|
      | 1 | 2 |
      {#table-first caption="First Table"}

      | X | Y |
      |---|---|
      | 3 | 4 |
      {#table-second caption="Second Table"}

      ## 参照

      図@<img>{fig-first}と図@<img>{fig-second}を参照してください。

      リスト@<list>{list-first}とリスト@<list>{list-second}を参照してください。

      表@<table>{table-first}と表@<table>{table-second}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    resolver = ReVIEW::AST::ReferenceResolver.new(chapter)
    resolver.resolve_references(ast)

    renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)
    output = renderer.render(ast)

    # 各参照が正しい番号でレンダリングされていることを確認
    assert_match(/図1\.1/, output, '最初の画像参照が正しくありません')
    assert_match(/図1\.2/, output, '2番目の画像参照が正しくありません')

    assert_match(/リスト1\.1/, output, '最初のリスト参照が正しくありません')
    assert_match(/リスト1\.2/, output, '2番目のリスト参照が正しくありません')

    assert_match(/表1\.1/, output, '最初のテーブル参照が正しくありません')
    assert_match(/表1\.2/, output, '2番目のテーブル参照が正しくありません')
  end

  def test_reference_html_link_structure
    markdown = <<~MD
      # Test Chapter

      ![Sample Image](images/sample.png)
      {#fig-sample caption="Sample Figure"}

      図@<img>{fig-sample}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    resolver = ReVIEW::AST::ReferenceResolver.new(chapter)
    resolver.resolve_references(ast)

    renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)
    output = renderer.render(ast)

    # <span class="imgref"><a href="./test.html#fig-sample">図1.1</a></span>
    assert_match(/<span class="imgref">/, output, 'imgrefクラスのspanが生成されていません')
    assert_match(%r{<a href="\./test\.html#fig-sample">}, output, 'リンクのhref属性が正しくありません')
    assert_match(%r{図1\.1</a>}, output, 'リンクテキストが正しくありません')
  end

  def test_nonexistent_reference
    markdown = <<~MD
      # Test Chapter

      ![Sample Image](images/sample.png)
      {#fig-sample caption="Sample Figure"}

      図@<img>{fig-nonexistent}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter, reference_resolution: false)

    resolver = ReVIEW::AST::ReferenceResolver.new(chapter)

    assert_raise(ReVIEW::CompileError) do
      resolver.resolve_references(ast)
    end
  end

  def test_image_caption_in_output
    markdown = <<~MD
      # Test Chapter

      ![Alt Text](images/sample.png)
      {#fig-sample caption="Sample Figure"}
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    resolver = ReVIEW::AST::ReferenceResolver.new(chapter)
    resolver.resolve_references(ast)

    renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)
    output = renderer.render(ast)

    assert_match(/!\[Sample Figure\]\(fig-sample\)/, output, '画像のキャプションが正しく出力されていません')
  end

  def test_list_caption_and_reference
    markdown = <<~MD
      # Test Chapter

      ```ruby {#list-example caption="Example Code"}
      def example
        puts "example"
      end
      ```

      上記のリスト@<list>{list-example}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    resolver = ReVIEW::AST::ReferenceResolver.new(chapter)
    resolver.resolve_references(ast)

    renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)
    output = renderer.render(ast)

    assert_match(/\*\*Example Code\*\*/, output, 'リストのキャプションが正しく出力されていません')

    assert_match(/リスト1\.1/, output, 'リスト参照が正しく出力されていません')
  end

  def test_table_caption_and_reference
    markdown = <<~MD
      # Test Chapter

      | Column 1 | Column 2 |
      |----------|----------|
      | Data 1   | Data 2   |
      {#table-example caption="Example Table"}

      上記の表@<table>{table-example}を参照してください。
    MD

    chapter = create_chapter(markdown)
    ast = @compiler.compile_to_ast(chapter)

    resolver = ReVIEW::AST::ReferenceResolver.new(chapter)
    resolver.resolve_references(ast)

    renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter)
    output = renderer.render(ast)

    assert_match(/\*\*Example Table\*\*/, output, 'テーブルのキャプションが正しく出力されていません')

    assert_match(/表1\.1/, output, 'テーブル参照が正しく出力されていません')
  end

  def test_chapter_references_with_multiple_chapters
    # Create a temporary directory with multiple chapters
    Dir.mktmpdir do |tmpdir|
      # Create book structure
      catalog_yml = File.join(tmpdir, 'catalog.yml')
      File.write(catalog_yml, "CHAPS:\n  - chapter1.md\n  - chapter2.md\n")

      config_yml = File.join(tmpdir, 'config.yml')
      File.write(config_yml, "bookname: test\nchapter_no: 1\n")

      # Create chapter 1
      chapter1_md = File.join(tmpdir, 'chapter1.md')
      File.write(chapter1_md, <<~MARKDOWN)
        # はじめに

        次の@<chap>{chapter2}を参照してください。

        @<title>{chapter2}の内容も重要です。

        詳しくは@<chapref>{chapter2}をご覧ください。
      MARKDOWN

      # Create chapter 2
      chapter2_md = File.join(tmpdir, 'chapter2.md')
      File.write(chapter2_md, "# 応用編\n\n内容...\n")

      # Load book
      book = ReVIEW::Book::Base.new(tmpdir)
      ReVIEW::I18n.setup(book.config['language'])

      # Build book-wide indexes BEFORE compilation
      require 'review/ast/book_indexer'
      ReVIEW::AST::BookIndexer.build(book)

      chapter1 = book.chapters[0]
      compiler = ReVIEW::AST::MarkdownCompiler.new
      ast = compiler.compile_to_ast(chapter1)

      resolver = ReVIEW::AST::ReferenceResolver.new(chapter1)
      resolver.resolve_references(ast)

      renderer = ReVIEW::Renderer::MarkdownRenderer.new(chapter1)
      output = renderer.render(ast)

      assert_match(/第2章/, output, '@<chap>{chapter2}が「第2章」としてレンダリングされていません')
      assert_match(/応用編/, output, '@<title>{chapter2}が「応用編」としてレンダリングされていません')
      assert_match(/第2章「応用編」/, output, '@<chapref>{chapter2}が「第2章「応用編」」としてレンダリングされていません')
    end
  end

  def test_chapter_title_extraction_from_markdown
    Dir.mktmpdir do |tmpdir|
      catalog_yml = File.join(tmpdir, 'catalog.yml')
      File.write(catalog_yml, "CHAPS:\n  - test.md\n")

      config_yml = File.join(tmpdir, 'config.yml')
      File.write(config_yml, "bookname: test\n")

      test_md = File.join(tmpdir, 'test.md')
      File.write(test_md, "# テスト章タイトル\n\n内容...\n")

      book = ReVIEW::Book::Base.new(tmpdir)

      # Build book-wide indexes to extract chapter titles
      require 'review/ast/book_indexer'
      ReVIEW::AST::BookIndexer.build(book)

      chapter = book.chapters.first

      assert_equal 'テスト章タイトル', chapter.title, '章タイトルが正しく抽出されていません'
    end
  end
end
