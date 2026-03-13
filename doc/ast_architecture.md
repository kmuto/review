# Re:VIEW AST / Renderer Architecture Overview

This document provides an organized view of the roles and processing flow of AST and Renderer, based on the latest implementation of Re:VIEW (sources under `lib/review/ast` and `lib/review/renderer`, as well as tests under `test/ast`).

## Overall Pipeline

1. `AST::Compiler` reads the body of each chapter (`ReVIEW::Book::Chapter`) and builds an AST with `DocumentNode` as the root (`lib/review/ast/compiler.rb`).
2. After AST generation, reference resolution (`ReferenceResolver`) and various post-processors (`TsizeProcessor` / `FirstLineNumProcessor` / `NoindentProcessor` / `OlnumProcessor` / `ListStructureNormalizer` / `ListItemNumberingProcessor` / `AutoIdProcessor`) are applied to organize structure and metadata.
3. Renderers traverse the built AST using the Visitor pattern and convert it to format-specific output such as HTML, LaTeX, IDGXML, etc. (`lib/review/renderer`).
4. `AST::Command::EpubMaker` / `AST::Command::PdfMaker` / `AST::Command::IdgxmlMaker`, which inherit from existing `EPUBMaker` / `PDFMaker` / `IDGXMLMaker`, create AST-based pipelines consisting of Compiler and Renderer.

## Details of `AST::Compiler`

### Main Responsibilities
- Sequentially reads Re:VIEW notation (`.re`) or Markdown (`.md`) source and builds AST nodes for each element (`compile_to_ast`, `build_ast_from_chapter`).
  - `.re` files: `AST::Compiler` directly parses and builds AST
  - `.md` files: `MarkdownCompiler` builds AST via Markly (see [Markdown Support](#markdown-support) section)
- Delegates inline notation to `InlineProcessor`, block commands to `BlockProcessor`, and lists to `ListProcessor` for assembly.
- Attaches `SnapshotLocation` containing position information such as line numbers to each node, making it available for error reporting and rendering.
- Oversees the pipeline including reference resolution and post-processing, aggregating detected errors and notifying them as `CompileError`.

### Input Scanning and Node Generation

#### Re:VIEW Format (`.re` files)
- `build_ast_from_chapter` uses `LineInput` to parse line by line, determining headings, paragraphs, block commands, lists, etc. (`case` branches in `lib/review/ast/compiler.rb`).
- Headings (`compile_headline_to_ast`) parse level, tag, label, and caption, storing them in `HeadlineNode`.
- Paragraphs (`compile_paragraph_to_ast`) are delimited by blank lines, passing inline elements to `InlineProcessor.parse_inline_elements` to generate children of `ParagraphNode`.
- Block commands (`compile_block_command_to_ast`) use `BlockProcessor` to return appropriate nodes such as `BlockNode`, `CodeBlockNode`, `TableNode`, etc.
  - `BlockData` (`lib/review/ast/block_data.rb`): An immutable data structure using `Data.define` that encapsulates block command information (name, arguments, lines, nested blocks, location info), separating IO reading from block processing responsibilities.
  - `BlockContext` and `BlockReader` (`lib/review/ast/compiler/`) handle parsing and reading of block commands.
- List types (`compile_ul_to_ast` / `compile_ol_to_ast` / `compile_dl_to_ast`) are parsed and assembled through `ListProcessor`.

#### Markdown Format (`.md` files)
- `MarkdownCompiler` uses `Markly.parse` to convert Markdown to a CommonMark-compliant Markly AST (`lib/review/ast/markdown_compiler.rb`).
- `MarkdownAdapter` traverses the Markly AST and converts each element to Re:VIEW AST nodes (`lib/review/ast/markdown_adapter.rb`).
  - Headings → `HeadlineNode`
  - Paragraphs → `ParagraphNode`
  - Code blocks → `CodeBlockNode` + `CodeLineNode`
  - Lists → `ListNode` + `ListItemNode`
  - Tables → `TableNode` + `TableRowNode` + `TableCellNode`
  - Inline elements (bold, italic, code, links, etc.) → `InlineNode` + `TextNode`
- Column markers are detected using `MarkdownHtmlNode` and converted to `ColumnNode`.
- The converted AST goes through the same post-processing pipeline (reference resolution, etc.) as `.re` files.

### Reference Resolution and Post-processing
- `ReferenceResolver` traverses the AST as a Visitor and replaces `ReferenceNode` under `InlineNode` with information from corresponding elements (`lib/review/ast/reference_resolver.rb`). Resolution results are stored as `ResolvedData`, which Renderers format for output.
- The post-processing pipeline is applied in the following order (see `compile_to_ast`):
  1. `TsizeProcessor`: Pre-applies `//tsize` information.
  2. `FirstLineNumProcessor`: Sets initial values for line-numbered code blocks.
  3. `NoindentProcessor` / `OlnumProcessor`: Attaches `//noindent`, `//olnum` directives as attributes to paragraphs and lists.
  4. `ListStructureNormalizer`: Formats list structures containing `//beginchild` / `//endchild` and removes unnecessary blocks.
  5. `ListItemNumberingProcessor`: Determines `item_number` for numbered lists.
  6. `AutoIdProcessor`: Assigns automatic IDs and sequential numbers to hidden headings and columns.

## AST Node Hierarchy and Features

> See [ast_node.md](ast_node.md) for details. This section explains only the overview needed to understand the AST/Renderer architecture.

### Base Classes

AST nodes are composed of two base classes:

- `AST::Node` (`lib/review/ast/node.rb`): Abstract base class for all AST nodes
  - Child node management (`add_child()`, `remove_child()`, etc.)
  - Visitor pattern support (`accept(visitor)`, `visit_method_name()`)
  - Plain text conversion (`to_inline_text()`)
  - Attribute management and JSON serialization

- `AST::LeafNode` (`lib/review/ast/leaf_node.rb`): Base class for terminal nodes
  - No children (calling `add_child()` raises an error)
  - Has `content` attribute (always a string)
  - Subclasses: `TextNode`, `ImageNode`, `EmbedNode`, `FootnoteNode`, `TexEquationNode`

See the "Base Classes" section in [ast_node.md](ast_node.md) for detailed design principles and method descriptions.

### Major Node Types

AST is composed of various node types:

#### Document Structure
- `DocumentNode`: Root node for the entire chapter
- `HeadlineNode`: Headings (holds level, label, caption)
- `ParagraphNode`: Paragraphs
- `ColumnNode`, `MinicolumnNode`: Column elements

#### Lists
- `ListNode`: Entire list (`:ul`, `:ol`, `:dl`)
- `ListItemNode`: List items (holds nesting level, number, definition term)

See [ast_list_processing.md](ast_list_processing.md) for details.

#### Tables
- `TableNode`: Entire table
- `TableRowNode`: Rows (distinguishes header/body)
- `TableCellNode`: Cells

#### Code Blocks
- `CodeBlockNode`: Code blocks (language, caption info)
- `CodeLineNode`: Each line within code block

#### Inline Elements
- `InlineNode`: Inline commands (`@<b>`, `@<code>`, etc.)
- `TextNode`: Plain text
- `ReferenceNode`: References (`@<img>`, `@<list>`, etc., resolved later)

#### Others
- `ImageNode`: Images (LeafNode)
- `BlockNode`: Generic block elements
- `FootnoteNode`: Footnotes (LeafNode)
- `EmbedNode`, `TexEquationNode`: Embedded content (LeafNode)
- `CaptionNode`: Caption elements

See [ast_node.md](ast_node.md) for detailed attributes, methods, and usage examples for each node.

### Serialization

All nodes implement `serialize_to_hash`, and `JSONSerializer` provides saving/restoring in JSON format (`lib/review/ast/json_serializer.rb`). This enables AST debugging, integration with external tools, and AST structure analysis.

## Inline and Reference Processing

- `InlineProcessor` (`lib/review/ast/inline_processor.rb`) works with `InlineTokenizer` to parse `@<cmd>{...}` / `@<cmd>$...$` / `@<cmd>|...|` and generate `InlineNode` and `TextNode`. Special commands (`ruby`, `href`, `kw`, `img`, `list`, `table`, `eq`, `fn`, etc.) build AST with dedicated methods.
- Data after reference resolution is used for caption generation and link creation in Renderers.

## List Processing Pipeline

> See [ast_list_processing.md](ast_list_processing.md) for details. This section explains only the overview needed for architecture understanding.

List processing consists of the following components:

### Main Components

- ListParser: Parses Re:VIEW list notation and generates `ListItemData` structures (`lib/review/ast/list_parser.rb`)
- NestedListAssembler: Builds nested AST structure (`ListNode`/`ListItemNode`) from `ListItemData`
- ListProcessor: Oversees parser and assembler, providing a unified interface to the compiler (`lib/review/ast/list_processor.rb`)

### Post-processing

- ListStructureNormalizer: Normalizes `//beginchild`/`//endchild` and merges consecutive lists (`lib/review/ast/compiler/list_structure_normalizer.rb`)
- ListItemNumberingProcessor: Assigns `item_number` to each item in numbered lists (`lib/review/ast/compiler/list_item_numbering_processor.rb`)

See [ast_list_processing.md](ast_list_processing.md) for detailed processing flow, data structures, and design principles.

## AST::Visitor and Indexer

- `AST::Visitor` (`lib/review/ast/visitor.rb`) is the base class for traversing AST.
  - Dynamic dispatch: Each node's `visit_method_name()` method returns the appropriate visit method name (`:visit_headline`, `:visit_paragraph`, etc.) and calls the corresponding method in the Visitor.
  - Main methods: `visit(node)`, `visit_all(nodes)`, `extract_text(node)` (private), `process_inline_content(node)` (private)
  - Subclasses: `Renderer::Base`, `ReferenceResolver`, `Indexer`, etc. inherit from this to realize AST traversal and processing.
- `AST::Indexer` (`lib/review/ast/indexer.rb`) inherits from `Visitor` and builds indexes for figures, tables, lists, code blocks, equations, etc. during AST traversal. Used for reference resolution and sequential numbering, Renderers obtain index information through Indexer when traversing AST.

## Renderer Layer

- `Renderer::Base` (`lib/review/renderer/base.rb`) inherits from `AST::Visitor` and provides foundational processing such as `render`, `render_children`, `render_inline_element`. Format-specific classes override `visit_*` methods.
- `RenderingContext` (`lib/review/renderer/rendering_context.rb`) manages state during rendering (inside tables, captions, definition lists, etc.) and footnote collection, mainly for HTML/LaTeX/IDGXML renderers, supporting switching to `footnotetext` and determining nesting conditions.
- Format-specific Renderers:
  - `HtmlRenderer` generates output compatible with HTMLBuilder, reproducing heading anchors, list formatting, footnote processing (`lib/review/renderer/html_renderer.rb`). Uses `InlineElementHandler` and `InlineContext` (`lib/review/renderer/html/`) for context-dependent inline element processing.
  - `LatexRenderer` reproduces LaTeXBuilder behavior (section counters, TOC, environment control, footnotes) while organizing handling with `RenderingContext` (`lib/review/renderer/latex_renderer.rb`). Uses `InlineElementHandler` and `InlineContext` (`lib/review/renderer/latex/`) for context-dependent inline element processing.
  - `IdgxmlRenderer`, `MarkdownRenderer`, `PlaintextRenderer` also inherit from `Renderer::Base` to realize direct output from AST.
  - `TopRenderer` converts to text-based manuscript format and adds proofreading marks (`lib/review/renderer/top_renderer.rb`).
- `renderer/rendering_context.rb` and renderers using it (HTML/LaTeX/IDGXML) use `FootnoteCollector` for batch processing of footnotes, replacing complex state management from the Builder era.

## Markdown Support

> See [ast_markdown.md](ast_markdown.md) for details. This section explains only the overview needed for architecture understanding.

Re:VIEW supports GitHub Flavored Markdown (GFM) and can convert `.md` files to Re:VIEW AST.

### Architecture

Markdown support consists of three main components:

- MarkdownCompiler (`lib/review/ast/markdown_compiler.rb`): Oversees compiling entire Markdown documents to Re:VIEW AST. Initializes Markly parser and enables GFM extensions (strikethrough, table, autolink, tagfilter).
- MarkdownAdapter (`lib/review/ast/markdown_adapter.rb`): Adapter layer that converts Markly AST (CommonMark compliant) to Re:VIEW AST. Converts each Markdown element to corresponding Re:VIEW AST nodes and manages column stack, list stack, and table stack.
- MarkdownHtmlNode (`lib/review/ast/markdown_html_node.rb`): Auxiliary node for parsing HTML elements in Markdown and identifying HTML comments with special meaning (column markers, etc.). Not included in final AST, used only during conversion processing.

### Conversion Process Flow

```
Markdown document → Markly.parse → Markly AST
                                    ↓
                          MarkdownAdapter.convert
                                    ↓
                             Re:VIEW AST
                                    ↓
                          Reference resolution & post-processing
                                    ↓
                             Renderers
```

### Supported Features

- GFM extensions: Strikethrough, tables, autolink, tag filtering
- Re:VIEW-specific extensions:
  - Column syntax (HTML comment: `<!-- column: Title -->` / `<!-- /column -->`)
  - Column syntax (heading: `### [column] Title` / `### [/column]`)
  - Automatic column closing (based on heading level)
  - Standalone image detection (converts single images in paragraphs to block-level `ImageNode`)

### Limitations

The following Re:VIEW-specific features are not supported in Markdown:
- `//list` (code block with caption) → Treated as regular code block
- `//table` (table with caption) → GFM tables can be used but cannot have captions or labels
- `//footnote` (footnotes)
- Some inline commands (`@<kw>`, `@<bou>`, etc.)

See [ast_markdown.md](ast_markdown.md) for details.

## Integration with Existing Tools

- Maker classes for EPUB/PDF/IDGXML, etc. (`AST::Command::EpubMaker`, `AST::Command::PdfMaker`, `AST::Command::IdgxmlMaker`) each define `RendererConverterAdapter` classes internally to adapt Renderer to the traditional Converter interface (`lib/review/ast/command/epub_maker.rb`, `pdf_maker.rb`, `idgxml_maker.rb`). Each Adapter generates corresponding Renderers (`HtmlRenderer`, `LatexRenderer`, `IdgxmlRenderer`) per chapter and passes output directly to the typesetting pipeline.
- `lib/review/ast/command/compile.rb` provides the `review-ast-compile` CLI, directly executing the AST→Renderer pipeline for the format specified with `--target`. In `--check` mode, only AST generation and validation are performed.

## JSON / Development Support Tools

- `JSONSerializer` and `AST::Dumper` (`lib/review/ast/dumper.rb`) serialize AST to JSON, available for debugging and integration with external tools. `Options` control presence of location information and simple mode.
- `AST::ReviewGenerator` (`lib/review/ast/review_generator.rb`) regenerates Re:VIEW notation from AST, used for bidirectional conversion and diff verification.
- `lib/review/ast/diff/html.rb` / `idgxml.rb` / `latex.rb` perform hash comparison of Builder and Renderer output differences, used in `test/ast/test_html_renderer_builder_comparison.rb`, etc.

## Test Guarantees

- `test/ast/test_ast_comprehensive.rb` / `test_ast_complex_integration.rb` convert entire chapters to AST and verify node structure and rendering results.
- `test/ast/test_html_renderer_inline_elements.rb` and `test_html_renderer_join_lines_by_lang.rb` verify HTML-specific specifications such as inline elements and line break processing.
- `test/ast/test_list_structure_normalizer.rb`, `test_list_processor.rb` comprehensively cover complex lists and `//beginchild` normalization.
- `test/ast/test_ast_comprehensive_inline.rb` ensures special inline commands don't break in AST→Renderer round trips.
- `test/ast/test_markdown_adapter.rb`, `test_markdown_compiler.rb` verify Markdown AST conversion works correctly.

Through these implementations and tests, the new AST-centric pipeline and Renderer suite maintain output compatible with traditional Builders while providing structured data models and utilities.
