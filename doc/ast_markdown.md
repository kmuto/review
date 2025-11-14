# Re:VIEW Markdown Support

Re:VIEW supports GitHub Flavored Markdown (GFM) through the AST-based Markdown compiler. This document describes supported Markdown features and conversion methods to Re:VIEW AST.

## Overview

Markdown support is implemented on top of Re:VIEW's AST/Renderer architecture. Markdown documents are internally converted to Re:VIEW AST and treated equivalently to traditional Re:VIEW format (`.re` files).

### Bidirectional Conversion Support

Re:VIEW supports the following bidirectional conversions:

1. Markdown → AST → Various formats: Convert Markdown to AST using MarkdownCompiler and output with various Renderers
2. Re:VIEW → AST → Markdown: Convert Re:VIEW format to AST and output in Markdown format with MarkdownRenderer

This bidirectional conversion enables:
- Converting documents written in Markdown to PDF, EPUB, HTML, etc.
- Converting documents written in Re:VIEW to Markdown format for publishing on GitHub, etc.
- Mutual content conversion between different formats

### Architecture

Markdown support provides bidirectional conversion:

#### Markdown → Re:VIEW AST (Input)

- Markly: Fast CommonMark parser with GFM extensions (external gem)
- MarkdownCompiler: Oversees compiling Markdown documents to Re:VIEW AST
- MarkdownAdapter: Adapter layer that converts Markly AST to Re:VIEW AST
- MarkdownHtmlNode: Handles HTML element parsing and column marker detection (internal use)

#### Re:VIEW AST → Markdown (Output)

- MarkdownRenderer: Renderer that outputs Re:VIEW AST in Markdown format
  - Captions are output in `**Caption**` format
  - Images are output in `![alt](path)` format
  - Tables are output in GFM pipe style
  - Footnotes are output in `[^id]` notation

### Supported Extensions

The following GitHub Flavored Markdown extensions are enabled:
- strikethrough: Strikethrough text (`~~text~~`)
- table: Tables (pipe style)
- autolink: Autolinks (automatically converts `http://example.com` to links)

### Re:VIEW-Specific Extensions

In addition to standard GFM, the following Re:VIEW-specific extensions are supported:

- Column syntax: Column blocks starting with heading (`### [column] Title`) and ending with HTML comment (`<!-- /column -->`) or auto-close
- Auto column close: Automatic column closing based on heading level
- Attribute blocks: ID and caption specification using Pandoc/kramdown-compatible `{#id caption="..."}` syntax
- Re:VIEW reference notation: Figure/table/listing references using `@<img>{id}`, `@<list>{id}`, `@<table>{id}`
- Footnote support: Footnotes using Markdown standard `[^id]` notation

## Markdown Basic Syntax

Re:VIEW conforms to [CommonMark](https://commonmark.org/) and [GitHub Flavored Markdown (GFM)](https://github.github.com/gfm/) specifications. For details on standard Markdown syntax, refer to these official specifications.

### Main Supported Elements

The following Markdown elements are converted to Re:VIEW AST:

| Markdown Syntax | Description | Re:VIEW AST |
|----------------|-------------|-------------|
| Paragraph | Text block separated by blank lines | `ParagraphNode` |
| Headings (`#` to `######`) | 6 heading levels | `HeadlineNode` |
| Bold (`**text**`) | Strong emphasis | `InlineNode(:b)` |
| Italic (`*text*`) | Italic emphasis | `InlineNode(:i)` |
| Code (`` `code` ``) | Inline code | `InlineNode(:code)` |
| Link (`[text](url)`) | Hyperlink | `InlineNode(:href)` |
| Strikethrough (`~~text~~`) | Strikethrough (GFM extension) | `InlineNode(:del)` |
| Bulleted list (`*`, `-`, `+`) | Unordered list | `ListNode(:ul)` |
| Numbered list (`1.`, `2.`) | Ordered list | `ListNode(:ol)` |
| Code block (` ``` `) | Code block with language specification | `CodeBlockNode` |
| Code block + attributes | ID and caption with `{#id caption="..."}` | `CodeBlockNode(:list)` |
| Blockquote (`>`) | Quote block | `BlockNode(:quote)` |
| Table (GFM) | Pipe-style table | `TableNode` |
| Table + attributes | ID and caption with `{#id caption="..."}` | `TableNode` (with ID/caption) |
| Image (`![alt](path)`) | Image (standalone line is block, inline is inline) | `ImageNode` / `InlineNode(:icon)` |
| Image + attributes | ID and caption with `{#id caption="..."}` | `ImageNode` (with ID/caption) |
| Horizontal rule (`---`, `***`) | Divider | `BlockNode(:hr)` |
| HTML block | Raw HTML (preserved) | `EmbedNode(:html)` |
| Footnote reference (`[^id]`) | Reference to footnote | `InlineNode(:fn)` + `ReferenceNode` |
| Footnote definition (`[^id]: content`) | Footnote definition | `FootnoteNode` |
| Re:VIEW reference (`@<type>{id}`) | Reference to figures/tables/listings | `InlineNode(type)` + `ReferenceNode` |
| Definition list (Markdown output) | Term and description pairs | `DefinitionListNode` / `DefinitionItemNode` |

### Conversion Example

```markdown
## Heading

This is a paragraph with **bold** and *italic* text. You can also use `inline code`.

* Bulleted item 1
* Bulleted item 2

See the [official site](https://example.com) for details.
```

### Image Handling

Images are converted to different AST nodes depending on context:

#### Standalone Image (Block Level)

```markdown
![Figure 1 caption](image.png)
```
Standalone images are converted to `ImageNode` (block level), equivalent to Re:VIEW's `//image[image][Figure 1 caption]`.

#### Explicit ID and Caption Specification

You can explicitly specify ID and caption for images using attribute block syntax. The attribute block can be written on the same line as the image or on the next line:

```markdown
![alt text](images/sample.png){#fig-sample caption="Sample image"}
```

Or written on the next line:

```markdown
![alt text](images/sample.png)
{#fig-sample caption="Sample image"}
```

This sets `id="fig-sample"` and `caption="Sample image"` on the `ImageNode`. If attribute block caption is specified, it takes precedence. You can also specify only the ID:

```markdown
![Sample image](images/sample.png){#fig-sample}
```

Or:

```markdown
![Sample image](images/sample.png)
{#fig-sample}
```

In this case, the alt text "Sample image" is used as the caption.

#### Inline Images

```markdown
This is an ![icon](icon.png) inline image.
```
Inline images are converted to `InlineNode(:icon)`, equivalent to Re:VIEW's `@<icon>{icon.png}`.

## Columns (Re:VIEW Extension)

Re:VIEW supports column blocks within Markdown documents. Columns start with heading syntax and end with HTML comments or auto-close.

### Method 1: Heading Syntax + HTML Comment End

```markdown
### [column] Column Title

Write your column content here.

You can use all Markdown features within columns.

<!-- /column -->
```

For columns without title:

```markdown
### [column]

Column content without title.

<!-- /column -->
```

### Method 2: Heading Syntax (Auto-close)

Columns are automatically closed in the following cases:
- When encountering a heading of the same level
- When encountering a heading of higher level (smaller number)
- At document end

```markdown
### [column] Column Title

Write your column content here.

### Next Section
```

In this example, the column is automatically closed when the "Next Section" heading is encountered.

Example of auto-close at document end:

```markdown
### [column] Tips and Tricks

This column will be automatically closed at the end of the document.

No explicit end marker is needed.
```

Example with higher level heading:

```markdown
### [column] Subsection Column

Level 3 column.

## Main Section

This level 2 heading closes the level 3 column.
```

### Column Auto-close Rules

- Same level: `### [column]` closes when another `###` heading appears
- Higher level: `### [column]` closes when `##` or `#` heading appears
- Lower level: `### [column]` does not close when `####` or lower appears
- Document end: All open columns are automatically closed

### Column Nesting

Columns can be nested, but pay attention to heading levels:

```markdown
## [column] Outer Column

Outer column content.

### [column] Inner Column

Inner column content.

<!-- /column -->

Back to outer column.

<!-- /column -->
```

## Code Blocks and Lists (Re:VIEW Extension)

### Code Blocks with Captions

You can specify ID and caption for code blocks to use functionality equivalent to Re:VIEW's `//list` command. The attribute block is written after the language specification:

````markdown
```ruby {#lst-hello caption="Greeting program"}
def hello(name)
  puts "Hello, #{name}!"
end
```
````

By writing the attribute block `{#lst-hello caption="Greeting program"}` after the language specification, ID and caption are set on the code block. In this case, the `code_type` of `CodeBlockNode` becomes `:list`.

You can also specify only the ID:

````markdown
```ruby {#lst-example}
# code
```
````

Regular code blocks without attribute blocks are treated as `code_type: :emlist`.

Note: Attribute blocks for code blocks must be written on the opening backtick line. Unlike images and tables, they cannot be written on the next line.

## Tables (Re:VIEW Extension)

### Tables with Captions

You can specify ID and caption for GFM tables. The attribute block is written on the line immediately after the table:

```markdown
| Name | Age | Occupation |
|------|-----|------------|
| Alice| 25  | Engineer   |
| Bob  | 30  | Designer   |
{#tbl-users caption="User list"}
```

By writing the attribute block `{#tbl-users caption="User list"}` on the line immediately after the table, ID and caption are set on the table. This is equivalent to Re:VIEW's `//table` command.

## Figure/Table References (Re:VIEW Extension)

### References Using Re:VIEW Notation

You can use Re:VIEW reference notation within Markdown to reference figures, tables, and listings:

```markdown
![Sample image](images/sample.png)
{#fig-sample caption="Sample image"}

See Figure @<img>{fig-sample}.
```

```markdown
```ruby {#lst-hello caption="Greeting program"}
def hello
  puts "Hello, World!"
end
```

See Listing @<list>{lst-hello}.
```

```markdown
| Name | Age |
|------|-----|
| Alice| 25  |
{#tbl-users caption="User list"}

See Table @<table>{tbl-users}.
```

This notation is the same as Re:VIEW's standard reference notation. The reference IDs must correspond to the IDs specified in the attribute blocks above.

References are replaced with appropriate numbers in subsequent processing:
- `@<img>{fig-sample}` → "Figure 1.1"
- `@<list>{lst-hello}` → "Listing 1.1"
- `@<table>{tbl-users}` → "Table 1.1"

### Reference Resolution

References are replaced with appropriate figure/table/listing numbers in subsequent processing (reference resolution phase). They are represented as a combination of `InlineNode` and `ReferenceNode` in the AST.

## Footnotes (Re:VIEW Extension)

Markdown standard footnote notation is supported:

### Using Footnotes

```markdown
This is a footnote test[^1].

Multiple footnotes can also be used[^note].

[^1]: This is the first footnote.

[^note]: This is a named footnote.
  Multiple line content is
  also supported.
```

You can use footnote references `[^id]` and footnote definitions `[^id]: content`. Footnote definitions can span multiple lines, and indented lines are treated as continuations of the previous footnote.

### Conversion to FootnoteNode

Footnote definitions are converted to `FootnoteNode` and treated equivalently to Re:VIEW's `//footnote` command. Footnote references are represented as `InlineNode(:fn)`.

## Definition Lists (Markdown Output)

When converting Re:VIEW definition lists (`: term` format) to Markdown format, they are output in the following format:

### Basic Output Format

```markdown
**term**: description

**another term**: another description
```

Terms are emphasized in bold (`**term**`) followed by a colon, space, and description.

### When Terms Include Emphasis

When a term already includes bold (`**text**`) or emphasis (`@<b>{text}`), MarkdownRenderer does not wrap the term in bold to avoid double bold markup (`****text****`):

Re:VIEW input example:
```review
 : @<b>{Important} term
	Description
```

Markdown output:
```markdown
**Important** term: Description
```

In this way, emphasis elements within the term are preserved as is, and outer bold markup is not added.

### AST Representation of Definition Lists

Definition lists are represented in Re:VIEW AST with the following nodes:
- `DefinitionListNode`: Node representing the entire definition list
- `DefinitionItemNode`: Node representing individual term and description pairs
  - `term_children`: List of inline elements for the term
  - `children`: List of block elements for the description

MarkdownRenderer checks if `term_children` contains `InlineNode(:b)` or `InlineNode(:strong)`, and if so, omits the outer bold markup.

## Other Markdown Features

### Line Breaks
- Soft break: Single line break is converted to space
- Hard break: Two spaces at line end insert a line break

### HTML Blocks
Raw HTML blocks are preserved as `EmbedNode(:html)` and treated equivalently to Re:VIEW's `//embed[html]`. Inline HTML is also supported.

## Limitations and Notes

### File Extension

Markdown files must use the `.md` extension to be processed properly. The Re:VIEW system automatically detects file format by extension.

**Important:** Re:VIEW only supports the `.md` extension. The `.markdown` extension is not supported.

### Image Paths

Image paths must be relative paths from the project's image directory (default `images/`) or use Re:VIEW's image path conventions.

#### Example
```markdown
![Caption](sample.png)  <!-- References images/sample.png -->
```

### Re:VIEW-Specific Features

The following Re:VIEW features are supported within Markdown:

#### Supported Re:VIEW Features
- `//list` (code block with caption) → Can be specified with attribute block `{#id caption="..."}`
- `//table` (table with caption) → Can be specified with attribute block `{#id caption="..."}`
- `//image` (image with caption) → Can be specified with attribute block `{#id caption="..."}`
- `//footnote` (footnote) → Supports Markdown standard `[^id]` notation
- Figure/table references (`@<img>{id}`, `@<list>{id}`, `@<table>{id}`) → Fully supported
- Column (`//column`) → Supported with HTML comment or heading notation

#### Unsupported Re:VIEW-Specific Features
- Special block commands like `//cmd`, `//embed`, etc.
- Some inline commands (`@<kw>`, `@<bou>`, `@<ami>`, etc.)
- Complex table features (cell merging, custom column widths, etc.)

If you need access to all Re:VIEW features, use Re:VIEW format (`.re` files).

### Column Nesting

When nesting columns, pay attention to heading levels. Inner columns should use higher heading levels (larger numbers) than outer columns:

```markdown
## [column] Outer Column
Outer content

### [column] Inner Column
Inner content
<!-- /column -->

Back to outer column
<!-- /column -->
```

### HTML Comment Usage

HTML comment `<!-- /column -->` is used as a column end marker. When using as a general comment, be careful not to write `/column`:

```markdown
<!-- This is a normal comment (no problem) -->
<!-- Writing /column will be interpreted as a column end marker -->
```

## Usage

### Command-Line Tools

#### Conversion via AST (Recommended)

When converting Markdown files to various formats via AST, use AST-specific commands:

```bash
# Dump Markdown to JSON-formatted AST
review-ast-dump chapter.md > chapter.json

# Convert Markdown to Re:VIEW format
review-ast-dump2re chapter.md > chapter.re

# Generate EPUB from Markdown (via AST)
review-ast-epubmaker config.yml

# Generate PDF from Markdown (via AST)
review-ast-pdfmaker config.yml

# Generate InDesign XML from Markdown (via AST)
review-ast-idgxmlmaker config.yml
```

#### Using review-ast-compile

With the `review-ast-compile` command, you can directly convert Markdown to specified formats:

```bash
# Convert Markdown to JSON-formatted AST
review-ast-compile --target=ast chapter.md

# Convert Markdown to HTML (via AST)
review-ast-compile --target=html chapter.md

# Convert Markdown to LaTeX (via AST)
review-ast-compile --target=latex chapter.md

# Convert Markdown to InDesign XML (via AST)
review-ast-compile --target=idgxml chapter.md

# Convert Markdown to Markdown (via AST, normalization/formatting)
review-ast-compile --target=markdown chapter.md
```

Note: Specifying `--target=ast` outputs the generated AST structure in JSON format. This is useful for debugging and checking AST structure.

#### Converting Re:VIEW Format to Markdown Format

You can also convert Re:VIEW format (`.re` files) to Markdown format:

```bash
# Convert Re:VIEW file to Markdown
review-ast-compile --target=markdown chapter.re > chapter.md
```

This conversion allows you to output documents written in Re:VIEW in Markdown format. MarkdownRenderer outputs in the following formats:

- Code blocks: Captions are output in `**Caption**` format, followed by fenced code blocks
- Tables: Captions are output in `**Caption**` format, followed by GFM pipe-style tables
- Images: Output in Markdown standard `![alt](path)` format
- Footnotes: Output in Markdown standard `[^id]` notation

#### Compatibility with Traditional review-compile

The traditional `review-compile` command can still be used, but when utilizing AST/Renderer architecture, we recommend using `review-ast-compile` and various `review-ast-*maker` commands:

```bash
# Traditional method (kept for compatibility)
review-compile --target=html chapter.md
review-compile --target=latex chapter.md
```

### Project Configuration

Configure project to use Markdown:

```yaml
# config.yml
contentdir: src

# CATALOG.yml
CHAPS:
  - chapter1.md
  - chapter2.md
```

### Integration with Re:VIEW Projects

You can mix Markdown and Re:VIEW files in the same project:

```
project/
  ├── config.yml
  ├── CATALOG.yml
  └── src/
      ├── chapter1.re     # Re:VIEW format
      ├── chapter2.md     # Markdown format
      └── chapter3.re     # Re:VIEW format
```

## Sample

### Complete Document Example

````markdown
# Introduction to Ruby

Ruby is a dynamic, open source programming language with a focus on simplicity and productivity[^intro].

## Installation

To install Ruby, follow these steps:

1. Visit the [Ruby website](https://www.ruby-lang.org/en/)
2. Download the installer for your platform
3. Run the installer

### [column] Version Management

For managing Ruby installations, we recommend using version managers like **rbenv** or **RVM**.

<!-- /column -->

## Basic Syntax

A simple Ruby program example is shown in Listing @<list>{lst-hello}:

```ruby {#lst-hello caption="Hello World in Ruby"}
# Hello World in Ruby
puts "Hello, World!"

# Define a method
def greet(name)
  "Hello, #{name}!"
end

puts greet("Ruby")
```

### Variables

Ruby has several variable types (see Table @<table>{tbl-vars}):

| Type | Prefix | Example |
|------|--------|---------|
| Local | none | `variable` |
| Instance | `@` | `@variable` |
| Class | `@@` | `@@variable` |
| Global | `$` | `$variable` |
{#tbl-vars caption="Ruby variable types"}

## Project Structure

A typical Ruby project structure is shown in Figure @<img>{fig-structure}:

![Project structure diagram](images/ruby-structure.png)
{#fig-structure caption="Ruby project structure"}

## Summary

> Ruby is designed to make programmers happy.
>
> -- Yukihiro Matsumoto

For more information, see ~~official documentation~~ [Ruby Docs](https://docs.ruby-lang.org/)[^docs].

---

Happy coding! ![Ruby logo](ruby-logo.png)

[^intro]: Ruby was released by Yukihiro Matsumoto in 1995.

[^docs]: The official documentation includes rich tutorials and API references.
````

## Conversion Details

### AST Node Mapping

| Markdown Element | Re:VIEW AST Node |
|------------------|------------------|
| Paragraph | `ParagraphNode` |
| Heading | `HeadlineNode` |
| Bold | `InlineNode(:b)` |
| Italic | `InlineNode(:i)` |
| Code | `InlineNode(:code)` |
| Link | `InlineNode(:href)` |
| Strikethrough | `InlineNode(:del)` |
| Bulleted list | `ListNode(:ul)` |
| Numbered list | `ListNode(:ol)` |
| List item | `ListItemNode` |
| Code block | `CodeBlockNode` |
| Code block (with attributes) | `CodeBlockNode(:list)` |
| Blockquote | `BlockNode(:quote)` |
| Table | `TableNode` |
| Table (with attributes) | `TableNode` (with ID/caption) |
| Table row | `TableRowNode` |
| Table cell | `TableCellNode` |
| Standalone image | `ImageNode` |
| Standalone image (with attributes) | `ImageNode` (with ID/caption) |
| Inline image | `InlineNode(:icon)` |
| Horizontal rule | `BlockNode(:hr)` |
| HTML block | `EmbedNode(:html)` |
| Column (HTML comment/heading) | `ColumnNode` |
| Code block line | `CodeLineNode` |
| Footnote definition `[^id]: content` | `FootnoteNode` |
| Footnote reference `[^id]` | `InlineNode(:fn)` + `ReferenceNode` |
| Figure/table reference `@<type>{id}` | `InlineNode(type)` + `ReferenceNode` |
| Definition list (output only) | `DefinitionListNode` |
| Definition item (output only) | `DefinitionItemNode` |

### Location Information Tracking

All AST nodes include location information (`SnapshotLocation`) that tracks:
- Source file name
- Line number

This enables accurate error reporting and debugging.

### Implementation Architecture

Markdown support consists of three main components:

#### 1. MarkdownCompiler

`MarkdownCompiler` is responsible for compiling entire Markdown documents to Re:VIEW AST.

Main features:
- Initializing and configuring Markly parser
- Enabling GFM extensions (strikethrough, table, autolink)
- Enabling footnote support (Markly::FOOTNOTES)
- Re:VIEW inline notation protection (`@<xxx>{id}` notation protection)
- Coordination with MarkdownAdapter
- Overseeing AST generation

Re:VIEW notation protection:

MarkdownCompiler protects Re:VIEW inline notation (`@<xxx>{id}`) before parsing by Markly. Since Markly incorrectly interprets `@<xxx>` as HTML tags, `@<` is replaced with placeholder `@@REVIEW_AT_LT@@` before parsing and restored by MarkdownAdapter.

#### 2. MarkdownAdapter

`MarkdownAdapter` is the adapter layer that converts Markly AST to Re:VIEW AST.

##### ContextStack

MarkdownAdapter has an internal `ContextStack` class that manages hierarchical context during AST construction. This unifies state management like the following and guarantees exception safety:

- Managing nested structures like lists, tables, columns
- Exception-safe context switching with `with_context` method (automatic cleanup in `ensure` block)
- Searching for specific nodes in stack with `find_all`, `any?` methods
- Debug support with context validation (`validate!`)

Main features:
- Traversing and converting Markly AST
- Converting each Markdown element to corresponding Re:VIEW AST node
- Unified hierarchical context management with ContextStack
- Recursive processing of inline elements (using InlineTokenizer)
- Parsing attribute blocks and extracting IDs/captions
- Processing Re:VIEW inline notation (`@<xxx>{id}`)

Features:
- Exception-safe state management with ContextStack: All contexts (lists, tables, columns, etc.) are managed in a single ContextStack, guaranteeing exception safety with automatic cleanup in `ensure` blocks
- Auto column close: Automatically closes columns with same level or higher headings. Column level is stored in ColumnNode.level attribute and can be retrieved from ContextStack
- Standalone image detection: Converts images that exist alone in paragraphs (including those with attribute blocks) to block-level `ImageNode`. Correctly recognizes even when there's a line break between image and attribute block by ignoring `softbreak`/`linebreak` nodes
- Attribute block parser: Parses `{#id caption="..."}` format attributes to extract ID and caption
- Markly footnote support: Uses Markly's native footnote feature (Markly::FOOTNOTES) to process `[^id]` and `[^id]: content`
- Inline notation processing with InlineTokenizer: Parses Re:VIEW inline notation (`@<img>{id}`, etc.) with InlineTokenizer and converts to InlineNode and ReferenceNode

#### 3. MarkdownHtmlNode (Internal Use)

`MarkdownHtmlNode` is an auxiliary node for parsing HTML elements in Markdown and identifying HTML comments with special meaning (column markers, etc.).

Main features:
- Parsing HTML comments
- Detecting column end markers (`<!-- /column -->`)

Features:
- This node is not included in the final AST, used only during conversion processing
- Calls `end_column` method when column end marker (`<!-- /column -->`) is detected
- General HTML blocks are preserved as `EmbedNode(:html)`

#### 4. MarkdownRenderer

`MarkdownRenderer` is a renderer that outputs Re:VIEW AST in Markdown format.

Main features:
- Traversing Re:VIEW AST and converting to Markdown format
- Output in GFM-compatible Markdown notation
- Output of captioned elements in appropriate format

Output formats:
- Code block captions: Output in `**Caption**` format followed by fenced code block
- Table captions: Output in `**Caption**` format followed by GFM pipe-style table
- Images: Output in Markdown standard `![alt](path)` format
- Footnote references: Output in `[^id]` format
- Footnote definitions: Output in `[^id]: content` format

Features:
- Prioritizes pure Markdown format output
- Emphasizes compatibility with GFM (GitHub Flavored Markdown)
- Does not error on unresolved references, uses ref_id as is

### Conversion Process Flow

1. Preprocessing: MarkdownCompiler protects Re:VIEW inline notation (`@<xxx>{id}`)
   - Replace `@<` → `@@REVIEW_AT_LT@@` to prevent Markly misinterpretation

2. Parsing phase: Markly parses Markdown and generates Markly AST (CommonMark compliant)
   - Enable GFM extensions (strikethrough, table, autolink)
   - Enable footnote support (Markly::FOOTNOTES)

3. Conversion phase: MarkdownAdapter traverses Markly AST and converts each element to Re:VIEW AST node
   - Hierarchical context management with ContextStack
   - Parse attribute blocks `{#id caption="..."}` to extract ID and caption
   - Restore Re:VIEW inline notation placeholder and process with InlineTokenizer
   - Convert Markly footnote nodes (`:footnote_reference`, `:footnote_definition`) to FootnoteNode and InlineNode(:fn)

4. Post-processing phase: Properly close nested structures like columns and lists
   - Automatic cleanup with ContextStack's `ensure` block
   - Detect unclosed columns and report errors

```ruby
# Conversion flow
markdown_text → Preprocessing (@< placeholderization)
                         ↓
        Markly.parse (GFM extensions + footnote support)
                         ↓
                   Markly AST
                         ↓
              MarkdownAdapter.convert
        (ContextStack management, attribute block parsing,
         InlineTokenizer processing, footnote conversion)
                         ↓
                  Re:VIEW AST
```

### Column Processing Details

Columns start with heading syntax and end with HTML comments or auto-close:

#### Column Start (Heading Syntax)
- Detected in `process_heading` method
- Extract `[column]` marker from heading text
- Save heading level to ColumnNode.level attribute and push to ContextStack

#### Column End (Two Methods)

1. HTML comment syntax: `<!-- /column -->`
   - Detected in `process_html_block` method
   - Use `MarkdownHtmlNode` to identify column end marker
   - Call `end_column` method to pop from ContextStack

2. Auto-close: Same/higher level heading
   - `auto_close_columns_for_heading` method retrieves current ColumnNode from ContextStack and checks level attribute
   - If new heading level is less than or equal to current column level, auto-close column
   - Also automatically closes at document end (`close_all_columns`)

Column hierarchy is managed by ContextStack, and close determination is made by level attribute.

## Advanced Features

### Custom Processing

You can extend the `MarkdownAdapter` class to add custom processing:

```ruby
class CustomMarkdownAdapter < ReVIEW::AST::MarkdownAdapter
  # Override methods to customize behavior
end
```

### Integration with Renderers

AST generated from Markdown works with all Re:VIEW AST Renderers:
- HTMLRenderer: Output in HTML format
- LaTeXRenderer: Output in LaTeX format (for PDF generation)
- IDGXMLRenderer: Output in InDesign XML format
- MarkdownRenderer: Output in Markdown format (normalization/formatting)
- Other custom Renderers

By going through AST structure, documents written in Markdown are processed the same as traditional Re:VIEW format (`.re` files) and achieve the same output quality.

#### MarkdownRenderer Output Example

When converting Re:VIEW format to Markdown format, the output looks like this:

Re:VIEW input example:
````review
= Chapter Title

//list[sample][Sample code][ruby]{
def hello
  puts "Hello, World!"
end
//}

See Listing @<list>{sample}.

//table[data][Data table]{
Name	Age
-----
Alice	25
Bob	30
//}

 : API
	Application Programming Interface
 : @<b>{REST}
	Representational State Transfer
````

MarkdownRenderer output:
`````markdown
# Chapter Title

**Sample code**

```ruby
def hello
  puts "Hello, World!"
end
```

See Listing @<list>{sample}.

**Data table**

| Name | Age |
| :-- | :-- |
| Alice | 25 |
| Bob | 30 |

API: Application Programming Interface

REST: Representational State Transfer

`````

Notes:
- Captions are output in `**Caption**` format and placed immediately before code blocks or tables
- Definition list terms are output in bold, but if the term already contains emphasis (e.g., `@<b>{REST}`), outer bold is omitted to avoid double bold markup
- This generates human-readable, GFM-compatible Markdown

## Testing

Comprehensive tests for Markdown support are provided:

### Test Files

- `test/ast/test_markdown_adapter.rb`: MarkdownAdapter tests
- `test/ast/test_markdown_compiler.rb`: MarkdownCompiler tests
- `test/ast/test_markdown_renderer.rb`: MarkdownRenderer tests
- `test/ast/test_markdown_renderer_fixtures.rb`: Fixture-based MarkdownRenderer tests
- `test/ast/test_renderer_builder_comparison.rb`: Renderer and Builder output comparison tests

### Running Tests

```bash
# Run all tests
bundle exec rake test

# Run only Markdown-related tests
ruby test/ast/test_markdown_adapter.rb
ruby test/ast/test_markdown_compiler.rb
ruby test/ast/test_markdown_renderer.rb

# Run fixture tests
ruby test/ast/test_markdown_renderer_fixtures.rb
```

### Regenerating Fixtures

If you change MarkdownRenderer output format, you need to regenerate fixtures:

```bash
bundle exec ruby test/fixtures/generate_markdown_fixtures.rb
```

This regenerates Markdown fixture files in the `test/fixtures/markdown/` directory with the latest output format.

## References

- [CommonMark Specification](https://commonmark.org/)
- [GitHub Flavored Markdown Specification](https://github.github.com/gfm/)
- [Markly Ruby Gem](https://github.com/gjtorikian/markly)
- [Re:VIEW Format Documentation](format.md)
- [AST Overview](ast.md)
- [AST Architecture Details](ast_architecture.md)
- [AST Node Details](ast_node.md)
