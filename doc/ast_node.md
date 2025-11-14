# Re:VIEW AST::Node Overview

## Overview

Re:VIEW's AST (Abstract Syntax Tree) is a structured node tree of Re:VIEW format text that can be converted to various output formats.

## Basic Design Patterns

1. Visitor Pattern: Uses Visitor pattern for processing AST nodes
2. Composite Pattern: Node structure with parent-child relationships
3. Factory Pattern: Creation of CaptionNode, etc.
4. Serialization: Saving and restoring AST in JSON format

## Base Class: `AST::Node`

### Main Attributes
- `location`: Location information in source file (file name, line number)
- `parent`: Parent node (Node instance)
- `children`: Array of child nodes
- `type`: Node type (string)
- `id`: ID (if applicable)
- `content`: Content (if applicable)
- `original_text`: Original text

### Main Methods
- `add_child(child)`, `remove_child(child)`, `replace_child(old_child, new_child)`, `insert_child(idx, *nodes)`: Child node management
- `leaf_node?()`: Determines if it's a leaf node
- `reference_node?()`: Determines if it's a reference node
- `id?()`: Determines if it has an ID
- `add_attribute(key, value)`, `attribute?(key)`: Attribute management
- `visit_method_name()`: Returns method name as symbol for use in Visitor pattern
- `to_inline_text()`: Returns text representation without markup (raises exception for branch nodes, overridden in subclasses)
- `to_h`, `to_json`: Basic JSON serialization
- `serialize_to_hash(options)`: Extended serialization

### Design Principles
- Branch nodes: All node classes not inheriting from `LeafNode`. Can have child nodes (`ParagraphNode`, `InlineNode`, etc.)
- Leaf nodes: Inherit from `LeafNode`, cannot have child nodes (`TextNode`, `ImageNode`, etc.)
- `LeafNode` has `content` attribute, but subclasses can define their own attributes
- Do not mix `content` and `children` in the same node
    - Leaf nodes also have `children`, but always return an empty array (never `nil`)

## Base Class: `AST::LeafNode`

### Overview
- Parent class: Node
- Purpose: Base class for terminal nodes that cannot have children
- Features:
  - Has `content` attribute (always string, default is empty string)
  - Raises error when attempting to add child nodes
  - `leaf_node?` method returns `true`

### Main Methods
- `leaf_node?()`: Always returns `true`
- `children`: Always returns empty array
- `add_child(child)`: Raises error (cannot have children)
- `to_inline_text()`: Returns `content`

### Classes Inheriting from LeafNode
- `TextNode`: Plain text (and its subclass `ReferenceNode`)
- `ImageNode`: Images (but has `id`, `caption_node`, `metric` instead of `content`)
- `TexEquationNode`: LaTeX equations
- `EmbedNode`: Embedded content
- `FootnoteNode`: Footnote definitions

## Node Class Hierarchy

```
AST::Node (base class)
├── [Branch nodes] - Can have child nodes
│   ├── DocumentNode                    # Document root
│   ├── HeadlineNode                    # Headings (=, ==, ===)
│   ├── ParagraphNode                   # Paragraph text
│   ├── InlineNode                      # Inline elements (@<b>{}, @<code>{}, etc.)
│   ├── CaptionNode                     # Caption (text + inline elements)
│   ├── ListNode                        # List (ul, ol, dl)
│   │   └── ListItemNode               # List item
│   ├── TableNode                       # Table
│   │   ├── TableRowNode               # Table row
│   │   └── TableCellNode              # Table cell
│   ├── CodeBlockNode                   # Code block
│   │   └── CodeLineNode               # Code line
│   ├── BlockNode                       # Generic block (//quote, //read, etc.)
│   ├── ColumnNode                      # Column (====[column]{id})
│   └── MinicolumnNode                  # Mini-column (//note, //memo, etc.)
│
└── LeafNode (base class for leaf nodes) - Cannot have child nodes
    ├── TextNode                        # Plain text
    │   └── ReferenceNode              # Text node with reference information
    ├── ImageNode                       # Image (//image, //indepimage, etc.)
    ├── FootnoteNode                    # Footnote definition (//footnote)
    ├── TexEquationNode                 # LaTeX equation block (//texequation)
    └── EmbedNode                       # Embedded content (//embed, //raw)
```

### Node Classification

#### Structure Nodes (Containers)
- `DocumentNode`, `HeadlineNode`, `ParagraphNode`, `ListNode`, `TableNode`, `CodeBlockNode`, `BlockNode`, `ColumnNode`, `MinicolumnNode`

#### Content Nodes (Leaves)
- `TextNode`, `ReferenceNode`, `ImageNode`, `FootnoteNode`, `TexEquationNode`, `EmbedNode`

#### Special Nodes
- `InlineNode` (contains text but is an inline element)
- `CaptionNode` (mixed text and inline elements)
- `ReferenceNode` (subclass of TextNode, holds reference information)
- `ListItemNode`, `TableRowNode`, `TableCellNode`, `CodeLineNode` (specific to certain parent nodes)

## Node Class Details

### 1. Document Structure Nodes

#### `DocumentNode`

- Parent class: Node
- Attributes:
  - `title`: Document title
  - `chapter`: Related chapter
- Purpose: Root node of AST, represents entire document
- Example: One entire chapter file
- Features: Usually has HeadlineNode, ParagraphNode, BlockNode, etc. as children

#### `HeadlineNode`

- Parent class: Node
- Attributes:
  - `level`: Heading level (1-6)
  - `label`: Label (optional)
  - `caption_node`: Caption (CaptionNode instance)
- Purpose: `=`, `==`, `===` format headings
- Examples:
  - `= Chapter Title` → level=1, caption_node=CaptionNode
  - `=={label} Section Title` → level=2, label="label", caption_node=CaptionNode
- Methods: `to_s`: String representation for debugging

#### `ParagraphNode`

- Parent class: Node
- Purpose: Regular paragraph text
- Features: Contains TextNode and InlineNode as children
- Example: Regular text paragraph, text within lists

### 2. Text Content Nodes

#### `TextNode`

- Parent class: Node
- Attributes:
  - `content`: Text content (string)
- Purpose: Represents plain text
- Features: Leaf node (no children)
- Example: String in paragraph, string in inline element

#### `ReferenceNode`

- Parent class: TextNode
- Attributes:
  - `content`: Display text (inherited)
  - `ref_id`: Reference ID (main reference target)
  - `context_id`: Context ID (chapter ID, etc., optional)
  - `resolved`: Whether reference is resolved
  - `resolved_data`: Structured resolved data (ResolvedData)
- Purpose: Used as child node of reference inline elements (`@<img>{}`, `@<table>{}`, `@<fn>{}`, etc.)
- Features:
  - Subclass of TextNode, holds reference information
  - Immutable design (creates new instance when resolving reference)
  - Displays reference ID when unresolved, generates appropriate reference text when resolved
- Main methods:
  - `resolved?()`: Determines if reference is resolved
  - `with_resolved_data(data)`: Returns new resolved instance
- Example: `@<img>{sample-image}` → ReferenceNode(ref_id: "sample-image")

#### `InlineNode`

- Parent class: Node
- Attributes:
  - `inline_type`: Inline element type (string)
  - `args`: Argument array
- Purpose: Inline elements (`@<b>{}`, `@<code>{}`, etc.)
- Examples:
  - `@<b>{bold}` → inline_type="b", args=["bold"]
  - `@<href>{https://example.com,link}` → inline_type="href", args=["https://example.com", "link"]
- Features: Often contains TextNode as children

### 3. Code Block Nodes

#### `CodeBlockNode`

- Parent class: Node
- Attributes:
  - `lang`: Programming language (optional)
  - `caption_node`: Caption (CaptionNode instance)
  - `line_numbers`: Line number display flag
  - `code_type`: Code block type (`:list`, `:emlist`, `:listnum`, etc.)
  - `original_text`: Original code text
- Purpose: Code blocks like `//list`, `//emlist`, `//listnum`
- Features: Has `CodeLineNode` children
- Methods:
  - `original_lines()`: Original text line array
  - `processed_lines()`: Processed text line array

#### `CodeLineNode`

- Parent class: Node
- Attributes:
  - `line_number`: Line number (optional)
  - `original_text`: Original text
- Purpose: Each line in code block
- Features: Can include inline elements (Re:VIEW notation can be used)
- Example: Notation like `@<b>{emphasis}` in code

### 4. List Nodes

#### `ListNode`

- Parent class: Node
- Attributes:
  - `list_type`: List type (`:ul` (bulleted), `:ol` (ordered), `:dl` (definition))
  - `olnum_start`: Starting number for ordered list (optional)
- Purpose: Bulleted lists (`*`, `1.`, `: definition` format)
- Children: Array of `ListItemNode`

#### `ListItemNode`

- Parent class: Node
- Attributes:
  - `level`: Nesting level (1 or higher)
  - `number`: Number in ordered list (optional)
  - `item_type`: Item type (`:ul_item`, `:ol_item`, `:dt`, `:dd`)
- Purpose: List items
- Features: Can have nested lists and paragraphs as children

### 5. Table Nodes

#### `TableNode`

- Parent class: Node
- Attributes:
  - `caption_node`: Caption (CaptionNode instance)
  - `table_type`: Table type (`:table`, `:emtable`, `:imgtable`)
  - `metric`: Metric information (width settings, etc.)
- Special structure:
  - `header_rows`: Array of header rows
  - `body_rows`: Array of body rows
- Purpose: Tables from `//table` command
- Methods: Manages header and body rows separately

#### `TableRowNode`

- Parent class: Node
- Attributes:
  - `row_type`: Row type (`:header`, `:body`)
- Purpose: Table row
- Children: Array of `TableCellNode`

#### `TableCellNode`

- Parent class: Node
- Attributes:
  - `cell_type`: Cell type (`:th` (header) or `:td` (regular cell))
  - `colspan`, `rowspan`: Cell merge information (optional)
- Purpose: Table cell
- Features: Has TextNode and InlineNode as children

### 6. Media Nodes

#### `ImageNode`

- Parent class: Node
- Attributes:
  - `caption_node`: Caption (CaptionNode instance)
  - `metric`: Metric information (size, scale, etc.)
  - `image_type`: Image type (`:image`, `:indepimage`, `:numberlessimage`)
- Purpose: Images from `//image`, `//indepimage` commands
- Features: Leaf node
- Example: `//image[sample][Caption][scale=0.8]`

### 7. Special Block Nodes

#### `BlockNode`

- Parent class: Node
- Attributes:
  - `block_type`: Block type (`:quote`, `:read`, `:lead`, etc.)
  - `args`: Argument array
  - `caption_node`: Caption (CaptionNode instance, optional)
- Purpose: Generic block container (quotes, reads, etc.)
- Examples:
  - `//quote{ ... }` → block_type=":quote"
  - `//read[filename]` → block_type=":read", args=["filename"]

#### `ColumnNode`

- Parent class: Node
- Attributes:
  - `level`: Column level (usually 9)
  - `label`: Label (ID) — indexing complete
  - `caption_node`: Caption (CaptionNode instance)
  - `column_type`: Column type (`:column`)
- Purpose: Column from `//column` command, `====[column]{id} Title` format
- Features:
  - Treated like heading but independent content block
  - Can specify ID with `label` attribute, referenced with `@<column>{chapter|id}`
  - Indexed by AST::Indexer

#### `MinicolumnNode`

- Parent class: Node
- Attributes:
  - `minicolumn_type`: Mini-column type (`:note`, `:memo`, `:tip`, `:info`, `:warning`, `:important`, `:caution`, etc.)
  - `caption_node`: Caption (CaptionNode instance)
- Purpose: Mini-columns like `//note`, `//memo`, `//tip`
- Features: Small content blocks displayed in decorative boxes

#### `EmbedNode`

- Parent class: Node
- Attributes:
  - `lines`: Array of embedded content lines
  - `arg`: Argument (for single line)
  - `embed_type`: Embed type (`:block` or `:inline`)
- Purpose: Embedded content (`//embed`, `//raw`, etc.)
- Features: Leaf node, preserves raw content as is

#### `FootnoteNode`

- Parent class: Node
- Attributes:
  - `id`: Footnote ID
  - `content`: Footnote content
  - `footnote_type`: Footnote type (`:footnote` or `:endnote`)
- Purpose: Footnote definition from `//footnote` command
- Features:
  - Footnote definition part in document
  - Integrated processing with AST::FootnoteIndex (inline references and block definitions)
  - Duplicate ID issue and content display improvements complete

#### `TexEquationNode`

- Parent class: Node
- Attributes:
  - `label`: Equation ID (optional)
  - `caption_node`: Caption (CaptionNode instance)
  - `code`: LaTeX equation code
- Purpose: LaTeX equation block from `//texequation` command
- Features:
  - Reference function for equations with ID
  - Preserves LaTeX equation code as is
  - Managed by equation index

### 8. Special Nodes

#### `CaptionNode`

- Parent class: Node
- Special features:
  - Factory method `CaptionNode.parse(caption_text, location)`
  - Parsing text and inline elements
- Purpose: Contains inline elements and text in captions
- Methods:
  - `to_inline_text()`: Plain text conversion without markup (recursively processes children)
  - `contains_inline?()`: Checks if it contains inline elements
  - `empty?()`: Checks if empty
- Example: `this is @<b>{bold} caption` → TextNode + InlineNode + TextNode
- Design policy:
  - Always treated as structured node (children array)
  - Does not output string `caption` field in JSON output
  - Enforces design principle that captions should have structure

## Processing Systems

### Visitor Pattern (`Visitor`)

- Purpose: Dynamically determine processing method for each node
- Method naming convention: `visit_#{node_type}` (e.g., `visit_headline`, `visit_paragraph`)
- Method name determination: Each node's `visit_method_name()` method returns appropriate symbol
- Main methods:
  - `visit(node)`: Calls node's `visit_method_name()` to determine and execute appropriate visit method
  - `visit_all(nodes)`: Visits multiple nodes and returns array of results
- Example: `visit_headline(node)` is called for `HeadlineNode`
- Implementation details:
  - Node's `visit_method_name()` converts from CamelCase to snake_case
  - Removes `Node` suffix from class name and adds `visit_` prefix

### Index Systems (`Indexer`)

- Purpose: Generate various indexes from AST nodes
- Supported elements:
  - HeadlineNode: Heading index
  - ColumnNode: Column index
  - ImageNode, TableNode, ListNode: Various figure/table indexes

### Footnote Index (`FootnoteIndex`)

- Purpose: AST-specific footnote management system
- Features:
  - Integrated processing of inline references and block definitions
  - Resolution of duplicate ID issues
  - Maintains compatibility with traditional Book::FootnoteIndex

### 6. Data Structures (`BlockData`)

#### `BlockData`

- Definition: Immutable data structure using `Data.define`
- Purpose: Encapsulates block command information, separating IO reading from block processing responsibilities
- Parameters:
  - `name` [Symbol]: Block command name (e.g., `:list`, `:note`, `:table`)
  - `args` [Array<String>]: Command line arguments (default: `[]`)
  - `lines` [Array<String>]: Content lines within block (default: `[]`)
  - `nested_blocks` [Array<BlockData>]: Nested block commands (default: `[]`)
  - `location` [SnapshotLocation]: Source location information for error reporting
- Main methods:
  - `nested_blocks?()`: Determines if it has nested blocks
  - `line_count()`: Returns number of lines
  - `content?()`: Determines if it has content lines
  - `arg(index)`: Safely retrieves argument at specified index
- Usage example:
  - Compiler reads blocks and creates BlockData instances
  - BlockProcessor receives BlockData and generates appropriate AST nodes
- Features: Immutable design ensures data consistency and predictability

### 7. List Processing Architecture

List processing involves multiple components working together. See [doc/ast_list_processing.md](./ast_list_processing.md) for details.

#### `ListParser`

- Purpose: Parse Re:VIEW list notation
- Responsibilities:
  - Extract list items from raw text lines
  - Determine nesting levels
  - Collect continuation lines
- Data structure:
  - `ListItemData`: List item data defined with `Struct.new`
    - `type`: Item type (`:ul_item`, `:ol_item`, `:dt`, `:dd`)
    - `level`: Nesting level (default: 1)
    - `content`: Item content
    - `continuation_lines`: Array of continuation lines (default: `[]`)
    - `metadata`: Metadata hash (default: `{}`)
    - `with_adjusted_level(new_level)`: Returns new instance with adjusted level

#### `NestedListAssembler`

- Purpose: Assemble actual AST structure from parsed data
- Supported features:
  - Deep nesting up to 6 levels
  - Handling asymmetric and irregular patterns
  - Mixed list types (ordered, unordered, definition lists)
- Main methods:
  - `build_nested_structure(items, list_type)`: Build nested structure
  - `build_unordered_list(items)`: Build unordered list
  - `build_ordered_list(items)`: Build ordered list

#### `ListProcessor`

- Purpose: Coordinate entire list processing
- Responsibilities:
  - Coordinate ListParser and NestedListAssembler
  - Provide unified interface to compiler
- Internal components:
  - `@parser`: ListParser instance
  - `@nested_list_assembler`: NestedListAssembler instance
- Public accessors:
  - `parser`: Access to ListParser (read-only)
  - `nested_list_assembler`: Access to NestedListAssembler (read-only)
- Main methods:
  - `process_unordered_list(f)`: Process unordered list
  - `process_ordered_list(f)`: Process ordered list
  - `process_definition_list(f)`: Process definition list
  - `parse_list_items(f, list_type)`: Parse list items (for testing)
  - `build_list_from_items(items, list_type)`: Build list node from items

#### `ListStructureNormalizer`

- Purpose: Normalize list structure and ensure consistency
- Responsibilities:
  - Check consistency of nested list structures
  - Fix invalid nesting structures
  - Remove empty list nodes

#### `ListItemNumberingProcessor`

- Purpose: Manage numbers for ordered lists
- Responsibilities:
  - Assign sequential numbers
  - Manage numbers according to nesting level
  - Support custom starting numbers

### 8. Inline Element Renderer (`InlineElementRenderer`)

- Purpose: Separate inline element processing from LaTeX renderer
- Features:
  - Improved maintainability and testability
  - Unified method naming (`render_inline_xxx` format)
  - Full implementation of column reference functionality

### 9. JSON Serialization (`JSONSerializer`)

- Options class: Serialization settings
  - `simple_mode`: Simple mode (basic attributes only)
  - `include_location`: Include location information
  - `include_original_text`: Include original text
- Main methods:
  - `serialize(node, options)`: Convert AST to JSON format
  - `deserialize(json_data)`: Restore AST from JSON
- Usage: Save AST structure, debug, tool integration
- CaptionNode processing:
  - Does not output string `caption` field in JSON output
  - Always outputs structured node as `caption_node`
  - Can accept strings during deserialization for backward compatibility

### 10. Compiler (`Compiler`)

- Purpose: Generate AST from Re:VIEW content
- Coordinated components:
  - `InlineProcessor`: Process inline elements
  - `BlockProcessor`: Process block elements
  - `ListProcessor`: Process list structures (coordinates with ListParser, NestedListAssembler)
- Performance features: Compilation time measurement and tracking
- Main methods: `compile_to_ast(chapter)`: Generate AST from chapter

## Usage Examples and Patterns

### 1. Basic AST Structure Example
```
DocumentNode
├── HeadlineNode (level=1)
│   └── caption_node: CaptionNode
│       └── TextNode (content="Chapter Title")
├── ParagraphNode
│   ├── TextNode (content="This is ")
│   ├── InlineNode (inline_type="b")
│   │   └── TextNode (content="bold")
│   └── TextNode (content=" text.")
└── CodeBlockNode (lang="ruby", code_type="list")
    ├── CodeLineNode
    │   └── TextNode (content="puts 'Hello'")
    └── CodeLineNode
        └── TextNode (content="end")
```

### 2. Leaf Node Features
The following nodes do not have children (leaf nodes):
- `TextNode`: Plain text
- `ReferenceNode`: Text with reference information (subclass of TextNode)
- `ImageNode`: Image reference
- `EmbedNode`: Embedded content

### 3. Special Child Node Management
- `TableNode`: Manages rows classified in `header_rows`, `body_rows` arrays
- `CodeBlockNode`: Manages lines in `CodeLineNode` array
- `CaptionNode`: Mixed content of text and inline elements
- `ListNode`: Supports nested list structure

### 4. Node Location Information (`SnapshotLocation`)
- All nodes hold position in source file with `location` attribute
- Used for debugging and error reporting

### 5. Inline Element Types
Main inline element types:
- Text decoration: `b`, `i`, `tt`, `u`, `strike`
- Links: `href`, `link`
- References: `img`, `table`, `list`, `chap`, `hd`, `column` (column reference)
- Special: `fn` (footnote), `kw` (keyword), `ruby` (ruby)
- Math: `m` (inline math)
- Cross-chapter references: `@<column>{chapter|id}` format

### 6. Block Element Types
Main block element types:
- Basic: `quote`, `lead`, `flushright`, `centering`
- Code: `list`, `listnum`, `emlist`, `emlistnum`, `cmd`, `source`
- Tables: `table`, `emtable`, `imgtable`
- Media: `image`, `indepimage`
- Columns: `note`, `memo`, `tip`, `info`, `warning`, `important`, `caution`

## Implementation Notes

1. Node design principles:
   - Branch nodes inherit from `Node` and can have children
   - Leaf nodes inherit from `LeafNode` and cannot have children
   - Do not mix `content` and `children` in same node
   - Override `to_inline_text()` method appropriately

2. Avoid circular references: Be careful not to create circular references when managing parent-child relationships

3. Data/Class structure:
   - Intermediate representations use immutable data classes (`Data.define`), nodes use mutable regular classes
   - Leaf node subclasses don't have child node arrays

4. Extensibility: Structure that makes adding new node types easy
   - Separation of processing through Visitor pattern
   - Dynamic method dispatch through `visit_method_name()`

5. Compatibility: Maintain compatibility with existing Builder/Compiler system

6. CaptionNode consistency: Always treat captions as structured nodes (CaptionNode), not as strings

7. Immutable design: Data structures like `BlockData` use `Data.define` to ensure predictability and consistency

This AST system enables Re:VIEW to convert text format to structured data and support various output formats such as HTML, PDF, EPUB, etc.
