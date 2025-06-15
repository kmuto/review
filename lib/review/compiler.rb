# frozen_string_literal: true

# Copyright (c) 2009-2024 Minero Aoki, Kenshi Muto
# Copyright (c) 2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/extentions'
require 'review/preprocessor'
require 'review/exception'
require 'review/location'
require 'review/loggable'
require 'review/ast'
require 'review/ast_renderer'
require 'review/ast_compiler'
require 'strscan'
require 'set'

module ReVIEW
  class Compiler
    include Loggable

    MAX_HEADLINE_LEVEL = 6

    def initialize(builder, ast_mode: false, ast_elements: nil)
      @builder = builder
      @ast_mode = ast_mode
      # When ast_elements is not specified, use empty array
      # Otherwise, use the specified ast_elements
      @ast_elements = Set.new(ast_elements || [])

      ## commands which do not parse block lines in compiler
      @non_parsed_commands = %i[embed texequation graph]

      ## to decide escaping/non-escaping for text
      @command_name_stack = []

      @logger = ReVIEW.logger

      @ignore_errors = builder.is_a?(ReVIEW::IndexBuilder)

      @compile_errors = nil

      ## AST related - delegate to ASTCompiler when in AST mode
      if @ast_mode
        @ast_compiler = ASTCompiler.new(builder, ast_elements, self)
      end

      # Legacy AST fields for backward compatibility
      @ast_root = nil
      @current_ast_node = nil
      @ast_renderer = nil
    end

    attr_reader :builder, :previous_list_type

    def strategy
      error 'Compiler#strategy is obsoleted. Use Compiler#builder.'
      @builder
    end

    def non_escaped_commands
      if @builder.highlight?
        %i[list emlist listnum emlistnum cmd source]
      else
        []
      end
    end

    def compile(chap)
      @chapter = chap

      if @ast_mode
        # Ensure builder is bound even in AST mode
        f = LineInput.new(StringIO.new(@chapter.content))
        @builder.bind(self, @chapter, Location.new(@chapter.basename, f))

        @ast_compiler.compile_to_ast(chap)
        # Update legacy fields for backward compatibility
        @ast_root = @ast_compiler.ast_root
        @current_ast_node = @ast_compiler.current_ast_node
        @ast_renderer = @ast_compiler.ast_renderer
      else
        do_compile
      end

      if @compile_errors
        raise ApplicationError, "#{location.filename} cannot be compiled."
      end

      @builder.result
    end

    # Public AST interface - delegate to ASTCompiler when in AST mode
    def ast_result
      if @ast_mode && @ast_compiler
        @ast_compiler.ast_result
      else
        @ast_root
      end
    end

    # Get hybrid mode configuration for debugging
    def hybrid_mode_config
      if @ast_mode && @ast_compiler
        @ast_compiler.hybrid_mode_config
      else
        {
          mode: @ast_mode ? :legacy_ast : :traditional,
          ast_elements: @ast_elements.to_a,
          debug_enabled: false,
          statistics: {}
        }
      end
    end

    # Log AST element usage statistics
    def log_ast_statistics
      if @ast_mode && @ast_compiler
        @ast_compiler.log_ast_element_statistics
      end
    end

    # Check if element should be processed via AST
    def should_use_ast?(element)
      if @ast_mode && @ast_compiler
        @ast_compiler.should_use_ast?(element)
      else
        @ast_mode && (@ast_elements.empty? || @ast_elements.include?(element))
      end
    end

    # Build headline AST node - delegate to ASTCompiler when in AST mode
    def build_headline_ast(level, label, caption)
      if @ast_mode && @ast_compiler
        @ast_compiler.build_headline_ast(level, label, caption)
      else
        # Legacy implementation for non-AST mode
        node = AST::HeadlineNode.new(
          location: location,
          level: level,
          label: label,
          caption: caption
        )
        @current_ast_node.add_child(node) if @current_ast_node

        # Render immediately in hybrid mode
        if @ast_renderer
          # Special handling for JsonBuilder - pass AST node directly
          if @builder.instance_of?(::ReVIEW::JSONBuilder)
            @builder.add_ast_node(node)
          else
            @ast_renderer.send(:visit_headline, node)
          end
        end
      end
    end

    # Build paragraph AST node - delegate to ASTCompiler when in AST mode
    def build_paragraph_ast(lines)
      if @ast_mode && @ast_compiler
        @ast_compiler.build_paragraph_ast(lines)
      else
        # Legacy implementation for non-AST mode
        node = AST::ParagraphNode.new(location: location)

        # Parse inline elements in each line and create child nodes
        lines.each do |line|
          parse_inline_elements(line, node)
        end

        @current_ast_node.add_child(node) if @current_ast_node

        # Render immediately in hybrid mode
        if @ast_renderer
          # Special handling for JsonBuilder - pass AST node directly
          if @builder.instance_of?(::ReVIEW::JSONBuilder)
            @builder.add_ast_node(node)
          else
            @ast_renderer.send(:visit_paragraph, node)
          end
        end
      end
    end

    # Build unordered list AST
    def build_ulist_ast(f)
      @ast_compiler.build_ulist_ast(f) if @ast_compiler
    end

    # Build ordered list AST
    def build_olist_ast(f)
      @ast_compiler.build_olist_ast(f) if @ast_compiler
    end

    # Build definition list AST
    def build_dlist_ast(f)
      @ast_compiler.build_dlist_ast(f) if @ast_compiler
    end

    # Parse inline elements and create AST nodes
    def parse_inline_elements(str, parent_node)
      return if str.empty?

      words = replace_fence(str).split(/(@<\w+>\{(?:[^}\\]|\\.)*?\})/, -1)
      words.each do |word|
        if word.match?(/\A@<\w+>\{.*?\}\z/)
          # This is an inline element
          create_inline_ast_node(word, parent_node)
        else
          # This is plain text
          unless word.empty?
            text_node = AST::TextNode.new(
              location: location,
              content: revert_replace_fence(word)
            )
            parent_node.add_child(text_node)
          end
        end
      end
    end

    # Create inline AST node
    def create_inline_ast_node(str, parent_node)
      match = /\A@<(\w+)>\{(.*?)\}\z/.match(revert_replace_fence(str.gsub('\\}', '}').gsub('\\\\', '\\')))
      return unless match

      op = match[1]
      arg = match[2]

      # Special handling for certain inline types
      case op
      when 'embed'
        create_inline_embed_ast_node(arg, parent_node)
      when 'ruby'
        create_inline_ruby_ast_node(arg, parent_node)
      when 'href'
        create_inline_href_ast_node(arg, parent_node)
      when 'kw'
        create_inline_kw_ast_node(arg, parent_node)
      when 'hd'
        create_inline_hd_ast_node(arg, parent_node)
      when 'img', 'list', 'table', 'eq'
        create_inline_ref_ast_node(op, arg, parent_node)
      when 'chap', 'chapref', 'sec', 'secref', 'labelref', 'ref'
        create_inline_cross_ref_ast_node(op, arg, parent_node)
      when 'w', 'wb'
        create_inline_word_ast_node(op, arg, parent_node)
      else
        # Standard inline processing
        inline_node = AST::InlineNode.new(
          location: location,
          inline_type: op,
          args: [arg]
        )

        # Handle nested inline elements in the argument
        if arg.include?('@<')
          parse_inline_elements(arg, inline_node)
        else
          # Simple text argument
          text_node = AST::TextNode.new(
            location: location,
            content: arg
          )
          inline_node.add_child(text_node)
        end

        parent_node.add_child(inline_node)
      end
    end

    # Create inline embed AST node
    def create_inline_embed_ast_node(arg, parent_node)
      node = AST::EmbedNode.new(
        location: location,
        embed_type: :inline,
        lines: [arg],
        arg: arg
      )
      parent_node.add_child(node)
    end

    # Create inline ruby AST node
    def create_inline_ruby_ast_node(arg, parent_node)
      inline_node = AST::InlineNode.new(
        location: location,
        inline_type: 'ruby'
      )

      # Parse ruby format: "base_text,ruby_text"
      if arg.include?(',')
        parts = arg.split(',', 2)
        inline_node.args = [parts[0].strip, parts[1].strip]

        # Add text nodes for both parts
        parent_text = AST::TextNode.new(
          location: location,
          content: parts[0].strip
        )
        inline_node.add_child(parent_text)

        ruby_text = AST::TextNode.new(
          location: location,
          content: parts[1].strip
        )
        inline_node.add_child(ruby_text)
      else
        inline_node.args = [arg]
        text_node = AST::TextNode.new(
          location: location,
          content: arg
        )
        inline_node.add_child(text_node)
      end

      parent_node.add_child(inline_node)
    end

    # Create inline href AST node
    def create_inline_href_ast_node(arg, parent_node)
      inline_node = AST::InlineNode.new(
        location: location,
        inline_type: 'href'
      )

      # Parse href format: "URL" or "URL, display_text"
      text_content = if arg.include?(',')
                       parts = arg.split(',', 2)
                       inline_node.args = [parts[0].strip, parts[1].strip]
                       parts[1].strip # Display text
                     else
                       inline_node.args = [arg]
                       arg # URL as display text
                     end

      text_node = AST::TextNode.new(
        location: location,
        content: text_content
      )
      inline_node.add_child(text_node)

      parent_node.add_child(inline_node)
    end

    # Create inline kw AST node
    def create_inline_kw_ast_node(arg, parent_node)
      inline_node = AST::InlineNode.new(
        location: location,
        inline_type: 'kw'
      )

      # Parse kw format: "keyword" or "keyword, supplement"
      if arg.include?(',')
        parts = arg.split(',', 2)
        inline_node.args = [parts[0].strip, parts[1].strip]

        # Add text nodes for both parts
        main_text = AST::TextNode.new(
          location: location,
          content: parts[0].strip
        )
        inline_node.add_child(main_text)

        supplement_text = AST::TextNode.new(
          location: location,
          content: parts[1].strip
        )
        inline_node.add_child(supplement_text)
      else
        inline_node.args = [arg]
        text_node = AST::TextNode.new(
          location: location,
          content: arg
        )
        inline_node.add_child(text_node)
      end

      parent_node.add_child(inline_node)
    end

    # Create inline hd AST node
    def create_inline_hd_ast_node(arg, parent_node)
      inline_node = AST::InlineNode.new(
        location: location,
        inline_type: 'hd'
      )

      # Parse hd format: "chapter_id|heading" or just "heading"
      if arg.include?('|')
        parts = arg.split('|', 2)
        inline_node.args = [parts[0].strip, parts[1].strip]

        # Add text nodes for both parts
        chapter_text = AST::TextNode.new(
          location: location,
          content: parts[0].strip
        )
        inline_node.add_child(chapter_text)

        heading_text = AST::TextNode.new(
          location: location,
          content: parts[1].strip
        )
        inline_node.add_child(heading_text)
      else
        inline_node.args = [arg]
        text_node = AST::TextNode.new(
          location: location,
          content: arg
        )
        inline_node.add_child(text_node)
      end

      parent_node.add_child(inline_node)
    end

    # Create inline reference AST node (for img, list, table, eq)
    def create_inline_ref_ast_node(ref_type, arg, parent_node)
      inline_node = AST::InlineNode.new(
        location: location,
        inline_type: ref_type
      )

      # Parse reference format: "ID" or "chapter_id|ID"
      if arg.include?('|')
        parts = arg.split('|', 2)
        inline_node.args = [parts[0].strip, parts[1].strip]

        # Add text nodes for both parts
        chapter_text = AST::TextNode.new(
          location: location,
          content: parts[0].strip
        )
        inline_node.add_child(chapter_text)

        id_text = AST::TextNode.new(
          location: location,
          content: parts[1].strip
        )
        inline_node.add_child(id_text)
      else
        inline_node.args = [arg]
        text_node = AST::TextNode.new(
          location: location,
          content: arg
        )
        inline_node.add_child(text_node)
      end

      parent_node.add_child(inline_node)
    end

    # Create inline cross-reference AST node (for chap, chapref, sec, secref, labelref, ref)
    def create_inline_cross_ref_ast_node(ref_type, arg, parent_node)
      inline_node = AST::InlineNode.new(
        location: location,
        inline_type: ref_type
      )

      # Cross-references typically just have a single ID argument
      inline_node.args = [arg]
      text_node = AST::TextNode.new(
        location: location,
        content: arg
      )
      inline_node.add_child(text_node)

      parent_node.add_child(inline_node)
    end

    # Create inline word AST node (for w, wb)
    def create_inline_word_ast_node(word_type, arg, parent_node)
      inline_node = AST::InlineNode.new(
        location: location,
        inline_type: word_type
      )

      # Word expansion commands just have the filename argument
      inline_node.args = [arg]
      text_node = AST::TextNode.new(
        location: location,
        content: arg
      )
      inline_node.add_child(text_node)

      parent_node.add_child(inline_node)
    end

    # Build block command AST node (e.g., embed, list, table, etc.)
    def build_block_command_ast(command_name, args, lines)
      case command_name
      when :embed
        build_embed_ast(args, lines)
      when :list, :listnum
        build_list_ast(command_name, args, lines)
      when :emlist, :emlistnum
        build_emlist_ast(command_name, args, lines)
      when :source
        build_source_ast(args, lines)
      when :cmd
        build_cmd_ast(args, lines)
      when :table, :emtable, :imgtable
        build_table_ast(command_name, args, lines)
      when :image, :indepimage, :numberlessimage
        build_image_ast(command_name, args, lines)
      when :quote, :blockquote
        build_quote_ast(command_name, args, lines)
      when :note, :memo, :tip, :info, :warning, :important, :caution, :notice
        build_minicolumn_ast(command_name, args, lines)
      when :footnote, :endnote
        build_footnote_ast(command_name, args, lines)
      when :raw
        build_raw_ast(args, lines)
      else
        # Fallback to traditional processing for unknown commands
        syntax = syntax_descriptor(command_name)
        if syntax&.block_allowed?
          @builder.__send__(command_name, lines || [], *args)
        else
          @builder.__send__(command_name, *args)
        end
      end
    end

    # Build embed AST node
    def build_embed_ast(args, lines)
      node = AST::EmbedNode.new(
        location: location,
        embed_type: :block,
        lines: lines || [],
        arg: args&.any? ? args.first : nil
      )
      @current_ast_node.add_child(node)

      # Render immediately in hybrid mode
      if @ast_renderer
        # Special handling for JsonBuilder - pass AST node directly
        if @builder.instance_of?(::ReVIEW::JSONBuilder)
          @builder.add_ast_node(node)
        else
          @ast_renderer.send(:visit_embed, node)
        end
      end
    end

    # Build list/listnum AST node
    def build_list_ast(command_name, args, lines)
      node = AST::CodeBlockNode.new(
        location: location,
        id: args&.any? ? args[0] : nil,
        caption: args && args.size > 1 ? args[1] : nil,
        lang: args && args.size > 2 ? args[2] : nil,
        lines: lines || [],
        line_numbers: (command_name == :listnum)
      )
      @current_ast_node.add_child(node)

      # Render immediately in hybrid mode
      if @ast_renderer
        @ast_renderer.send(:visit_code_block, node)
      end
    end

    # Build emlist/emlistnum AST node
    def build_emlist_ast(command_name, args, lines)
      node = AST::CodeBlockNode.new(
        location: location,
        caption: args&.any? ? args[0] : nil,
        lang: args && args.size > 1 ? args[1] : nil,
        lines: lines || [],
        line_numbers: (command_name == :emlistnum)
      )
      @current_ast_node.add_child(node)

      # Render immediately in hybrid mode
      if @ast_renderer
        @ast_renderer.send(:visit_code_block, node)
      end
    end

    # Build source AST node
    def build_source_ast(args, lines)
      node = AST::CodeBlockNode.new(
        location: location,
        caption: args&.any? ? args[0] : nil,
        lang: args && args.size > 1 ? args[1] : nil,
        lines: lines || []
      )
      @current_ast_node.add_child(node)

      # Render immediately in hybrid mode
      if @ast_renderer
        @ast_renderer.send(:visit_code_block, node)
      end
    end

    # Build cmd AST node
    def build_cmd_ast(args, lines)
      node = AST::CodeBlockNode.new(
        location: location,
        caption: args&.any? ? args[0] : nil,
        lang: 'shell',
        lines: lines || []
      )
      @current_ast_node.add_child(node)

      # Render immediately in hybrid mode
      if @ast_renderer
        @ast_renderer.send(:visit_code_block, node)
      end
    end

    # Build table AST node
    def build_table_ast(_command_name, args, lines)
      # Parse table content
      headers = []
      rows = []
      if lines && lines.any?
        separator_index = lines.find_index { |line| line.match?(/^[-=]{12,}$/) }
        if separator_index
          headers = lines[0...separator_index]
          rows = lines[(separator_index + 1)..-1] || []
        else
          rows = lines
        end
      end

      # Create TableNode with appropriate table_type and arguments based on command
      node = case _command_name
             when :table
               AST::TableNode.new(
                 location: location,
                 id: args&.any? ? args[0] : nil,
                 caption: args && args.size > 1 ? args[1] : nil,
                 headers: headers,
                 rows: rows,
                 table_type: :table
               )
             when :emtable
               AST::TableNode.new(
                 location: location,
                 id: nil,
                 caption: args&.any? ? args[0] : nil,
                 headers: headers,
                 rows: rows,
                 table_type: :emtable
               )
             when :imgtable
               AST::TableNode.new(
                 location: location,
                 id: args&.any? ? args[0] : nil,
                 caption: args && args.size > 1 ? args[1] : nil,
                 headers: headers,
                 rows: rows,
                 table_type: :imgtable,
                 metric: args && args.size > 2 ? args[2] : nil
               )
             else
               # Fallback for unknown table types
               AST::TableNode.new(
                 location: location,
                 id: args&.any? ? args[0] : nil,
                 caption: args && args.size > 1 ? args[1] : nil,
                 headers: headers,
                 rows: rows,
                 table_type: _command_name
               )
             end

      @current_ast_node.add_child(node)

      # Render immediately in hybrid mode
      if @ast_renderer
        @ast_renderer.send(:visit_table, node)
      end
    end

    # Build image AST node
    def build_image_ast(_command_name, args, _lines)
      node = AST::ImageNode.new(
        location: location,
        id: args&.any? ? args[0] : nil,
        caption: args && args.size > 1 ? args[1] : nil,
        metric: args && args.size > 2 ? args[2] : nil
      )
      @current_ast_node.add_child(node)

      # Render immediately in hybrid mode
      if @ast_renderer
        @ast_renderer.send(:visit_image, node)
      end
    end

    # Build quote AST node
    def build_quote_ast(command_name, _args, lines)
      node = AST::ParagraphNode.new(location: location)

      # Parse inline elements in quote content
      (lines || []).each do |line|
        parse_inline_elements(line, node)
      end

      @current_ast_node.add_child(node)

      # Render immediately in hybrid mode - use quote-specific method
      if @ast_renderer
        if command_name == :blockquote
          @builder.blockquote(lines || [])
        else
          @builder.quote(lines || [])
        end
      end
    end

    # Build minicolumn AST node (note, memo, tip, etc.)
    def build_minicolumn_ast(command_name, args, lines)
      node = AST::ParagraphNode.new(
        location: location,
        content: "#{command_name}: #{args.first || ''}"
      )

      # Parse inline elements in minicolumn content
      (lines || []).each do |line|
        parse_inline_elements(line, node)
      end

      @current_ast_node.add_child(node)

      # Render immediately in hybrid mode - use minicolumn-specific method
      if @ast_renderer
        @builder.__send__("#{command_name}_begin", args.first)
        (lines || []).each do |line|
          # Process inline elements in line for proper rendering
          processed_line = text(line)
          @builder.paragraph([processed_line])
        end
        @builder.__send__("#{command_name}_end")
      end
    end

    # Build footnote AST node
    def build_footnote_ast(command_name, args, _lines)
      # Footnotes are single-line commands, not block commands
      # Handle them as inline processing would
      if @ast_renderer
        @builder.__send__(command_name, *args)
      end
    end

    # Build raw AST node
    def build_raw_ast(args, lines)
      node = AST::EmbedNode.new(
        location: location,
        embed_type: :raw,
        lines: lines || [],
        arg: args&.any? ? args.first : nil
      )
      @current_ast_node.add_child(node)

      # Render immediately in hybrid mode
      if @ast_renderer && args&.any?
        @builder.raw(args.first)
      end
    end

    class SyntaxElement
      def initialize(name, type, argc, &block)
        @name = name
        @type = type
        @argc_spec = argc
        @checker = block
      end

      attr_reader :name

      def check_args(args)
        unless @argc_spec === args.size # rubocop:disable Style/CaseEquality
          raise CompileError, "wrong # of parameters (block command //#{@name}, expect #{@argc_spec} but #{args.size})"
        end

        if @checker
          @checker.call(*args)
        end
      end

      def min_argc
        case @argc_spec
        when Range then @argc_spec.begin
        when Integer then @argc_spec
        else
          raise TypeError, "argc_spec is not Range/Integer: #{inspect}"
        end
      end

      def minicolumn?
        @type == :minicolumn
      end

      def block_required?
        @type == :block or @type == :minicolumn
      end

      def block_allowed?
        @type == :block or @type == :optional or @type == :minicolumn
      end
    end

    SYNTAX = {}

    def self.defblock(name, argc, optional = false, &block)
      defsyntax(name, (optional ? :optional : :block), argc, &block)
    end

    def self.defminicolumn(name, argc, _optional = false, &block)
      defsyntax(name, :minicolumn, argc, &block)
    end

    def self.defsingle(name, argc, &block)
      defsyntax(name, :line, argc, &block)
    end

    def self.defsyntax(name, type, argc, &block)
      SYNTAX[name] = SyntaxElement.new(name, type, argc, &block)
    end

    def self.definline(name)
      INLINE[name] = InlineSyntaxElement.new(name)
    end

    def self.minicolumn_names
      buf = []
      SYNTAX.each do |name, syntax|
        if syntax.minicolumn?
          buf << name.to_s
        end
      end
      buf
    end

    def syntax_defined?(name)
      SYNTAX.key?(name.to_sym)
    end

    def syntax_descriptor(name)
      SYNTAX[name.to_sym]
    end

    class InlineSyntaxElement
      def initialize(name)
        @name = name
      end

      attr_reader :name
    end

    INLINE = {}

    def inline_defined?(name)
      INLINE.key?(name.to_sym)
    end

    defblock :read, 0
    defblock :lead, 0
    defblock :list, 2..3
    defblock :emlist, 0..2
    defblock :cmd, 0..1
    defblock :table, 0..2
    defblock :imgtable, 0..3
    defblock :emtable, 0..1
    defblock :quote, 0
    defblock :image, 2..3, true
    defblock :source, 0..2
    defblock :listnum, 2..3
    defblock :emlistnum, 0..2
    defblock :bibpaper, 2..3, true
    defblock :doorquote, 1
    defblock :talk, 0
    defblock :texequation, 0..2
    defblock :graph, 1..3
    defblock :indepimage, 1..3, true
    defblock :numberlessimage, 1..3, true

    defblock :address, 0
    defblock :blockquote, 0
    defblock :bpo, 0
    defblock :flushright, 0
    defblock :centering, 0
    defblock :box, 0..1
    defblock :comment, 0..1, true
    defblock :embed, 0..1

    defminicolumn :note, 0..1
    defminicolumn :memo, 0..1
    defminicolumn :tip, 0..1
    defminicolumn :info, 0..1
    defminicolumn :warning, 0..1
    defminicolumn :important, 0..1
    defminicolumn :caution, 0..1
    defminicolumn :notice, 0..1

    defsingle :footnote, 2
    defsingle :endnote, 2
    defsingle :printendnotes, 0
    defsingle :noindent, 0
    defsingle :blankline, 0
    defsingle :pagebreak, 0
    defsingle :hr, 0
    defsingle :parasep, 0
    defsingle :label, 1
    defsingle :raw, 1
    defsingle :tsize, 1
    defsingle :include, 1
    defsingle :olnum, 1
    defsingle :firstlinenum, 1
    defsingle :beginchild, 0
    defsingle :endchild, 0

    definline :chapref
    definline :chap
    definline :title
    definline :img
    definline :imgref
    definline :icon
    definline :list
    definline :table
    definline :eq
    definline :fn
    definline :endnote
    definline :kw
    definline :ruby
    definline :bou
    definline :ami
    definline :b
    definline :dtp
    definline :code
    definline :bib
    definline :hd
    definline :secref
    definline :sec
    definline :sectitle
    definline :href
    definline :recipe
    definline :column
    definline :tcy
    definline :balloon

    definline :abbr
    definline :acronym
    definline :cite
    definline :dfn
    definline :em
    definline :kbd
    definline :q
    definline :samp
    definline :strong
    definline :var
    definline :big
    definline :small
    definline :del
    definline :ins
    definline :sup
    definline :sub
    definline :tt
    definline :i
    definline :tti
    definline :ttb
    definline :u
    definline :raw
    definline :br
    definline :m
    definline :uchar
    definline :idx
    definline :hidx
    definline :comment
    definline :include
    definline :embed
    definline :pageref
    definline :w
    definline :wb
    definline :labelref
    definline :ref

    private

    def do_compile
      f = LineInput.from_string(@chapter.content)
      @builder.bind(self, @chapter, Location.new(@chapter.basename, f))
      @previous_list_type = nil

      ## in minicolumn, such as note/info/alert...
      @minicolumn_name = nil

      tagged_section_init
      while f.next?
        case f.peek
        when /\A\#@/
          f.gets # Nothing to do
        when /\A=+[\[\s{]/
          compile_headline(f.gets)
          @previous_list_type = nil
        when /\A\s+\*/
          compile_ulist(f)
          @previous_list_type = 'ul'
        when /\A\s+\d+\./
          compile_olist(f)
          @previous_list_type = 'ol'
        when /\A\s+:\s/
          compile_dlist(f)
          @previous_list_type = 'dl'
        when /\A\s*:\s/
          warn 'Definition list starting with `:` is deprecated. It should start with ` : `.', location: location
          compile_dlist(f)
          @previous_list_type = 'dl'
        when %r{\A//\}}
          if in_minicolumn?
            _line = f.gets
            compile_minicolumn_end
          else
            f.gets
            error 'block end seen but not opened', location: location
          end
        when %r{\A//[a-z]+}
          line = f.peek
          matched = line =~ %r|\A//([a-z]+)(:?\[.*\])?{\s*$|
          if matched && minicolumn_block_name?($1)
            line = f.gets
            name = $1
            args = parse_args(line.sub(%r{\A//[a-z]+}, '').rstrip.chomp('{'), name)
            compile_minicolumn_begin(name, *args)
          else
            # @command_name_stack.push(name) ## <- move into read_command() to use name
            name, args, lines = read_command(f)
            syntax = syntax_descriptor(name)
            unless syntax
              error "unknown command: //#{name}", location: location
              @command_name_stack.pop
              next
            end
            compile_command(syntax, args, lines)
            @command_name_stack.pop
          end
          @previous_list_type = nil
        when %r{\A//}
          line = f.gets
          warn "`//' seen but is not valid command: #{line.strip.inspect}", location: location
          if block_open?(line)
            warn 'skipping block...', location: location
            read_block(f, false)
          end
          @previous_list_type = nil
        else
          if f.peek.strip.empty?
            f.gets
            next
          end
          compile_paragraph(f)
          @previous_list_type = nil
        end
      end
      close_all_tagged_section
    rescue SyntaxError => e
      error e, location: location
    end

    def compile_minicolumn_begin(name, caption = nil)
      mid = "#{name}_begin"
      unless @builder.respond_to?(mid)
        error "strategy does not support minicolumn: #{name}", location: location
      end

      if @minicolumn_name
        error "minicolumn cannot be nested: #{name}", location: location
        return
      end
      @minicolumn_name = name

      @builder.__send__(mid, caption)
    end

    def compile_minicolumn_end
      unless @minicolumn_name
        error "minicolumn is not used: #{name}", location: location
        return
      end
      name = @minicolumn_name

      mid = "#{name}_end"
      @builder.__send__(mid)
      @minicolumn_name = nil
    end

    def compile_headline(line)
      @headline_indexs ||= [@chapter.number.to_i - 1]
      m = /\A(=+)(?:\[(.+?)\])?(?:\{(.+?)\})?(.*)/.match(line)
      level = m[1].size
      if level > MAX_HEADLINE_LEVEL
        raise CompileError, "Invalid header: max headline level is #{MAX_HEADLINE_LEVEL}"
      end

      tag = m[2]
      label = m[3]
      caption = m[4].strip
      index = level - 1
      if tag
        if tag.start_with?('/')
          open_tag = tag[1..-1]
          prev_tag_info = @tagged_section.pop
          if prev_tag_info.nil? || prev_tag_info.first != open_tag
            error "#{open_tag} is not opened.", location: location
          end
          close_tagged_section(*prev_tag_info)
        else
          if caption.empty?
            warn 'headline is empty.', location: location
          end
          close_current_tagged_section(level)
          open_tagged_section(tag, level, label, caption)
        end
      else
        if caption.empty?
          warn 'headline is empty.', location: location
        end
        if @headline_indexs.size > (index + 1)
          @headline_indexs = @headline_indexs[0..index]
        end
        if @headline_indexs[index].nil?
          @headline_indexs[index] = 0
        end
        @headline_indexs[index] += 1
        close_current_tagged_section(level)

        if should_use_ast?(:headline)
          build_headline_ast(level, label, caption)
        else
          @builder.headline(level, label, caption)
        end
      end
    end

    def close_current_tagged_section(level)
      while @tagged_section.last && (@tagged_section.last[1] >= level)
        close_tagged_section(* @tagged_section.pop)
      end
    end

    def headline(level, label, caption)
      @builder.headline(level, label, caption)
    end

    def tagged_section_init
      @tagged_section = []
    end

    def open_tagged_section(tag, level, label, caption)
      mid = "#{tag}_begin"
      unless @builder.respond_to?(mid)
        error "builder does not support tagged section: #{tag}", location: location
        headline(level, label, caption)
        return
      end
      @tagged_section.push([tag, level])
      @builder.__send__(mid, level, label, caption)
    end

    def close_tagged_section(tag, level)
      mid = "#{tag}_end"
      if @builder.respond_to?(mid)
        @builder.__send__(mid, level)
      else
        error "builder does not support block op: #{mid}", location: location
      end
    end

    def close_all_tagged_section
      until @tagged_section.empty?
        close_tagged_section(* @tagged_section.pop)
      end
    end

    def compile_ulist(f)
      if should_use_ast?(:ulist)
        build_ulist_ast(f)
      else
        compile_ulist_traditional(f)
      end
    end

    def compile_ulist_traditional(f)
      level = 0
      f.while_match(/\A\s+\*|\A\#@/) do |line|
        next if /\A\#@/.match?(line)

        buf = [text(line.sub(/\*+/, '').strip)]
        f.while_match(/\A\s+(?!\*)\S/) do |cont|
          buf.push(text(cont.strip))
        end

        line =~ /\A\s+(\*+)/
        current_level = $1.size
        if level == current_level
          @builder.ul_item_end
          # body
          @builder.ul_item_begin(buf)
        elsif level < current_level # down
          level_diff = current_level - level
          if level_diff != 1
            error 'too many *.', location: location
          end
          level = current_level
          @builder.ul_begin { level }
          @builder.ul_item_begin(buf)
        elsif level > current_level # up
          level_diff = level - current_level
          level = current_level
          (1..level_diff).to_a.reverse_each do |i|
            @builder.ul_item_end
            @builder.ul_end { level + i }
          end
          @builder.ul_item_end
          # body
          @builder.ul_item_begin(buf)
        end
      end

      (1..level).to_a.reverse_each do |i|
        @builder.ul_item_end
        @builder.ul_end { i }
      end
    end

    def compile_olist(f)
      if should_use_ast?(:olist)
        build_olist_ast(f)
      else
        compile_olist_traditional(f)
      end
    end

    def compile_olist_traditional(f)
      @builder.ol_begin
      f.while_match(/\A\s+\d+\.|\A\#@/) do |line|
        next if /\A\#@/.match?(line)

        num = line.match(/(\d+)\./)[1]
        buf = [text(line.sub(/\d+\./, '').strip)]
        f.while_match(/\A\s+(?!\d+\.)\S/) do |cont|
          buf.push(text(cont.strip))
        end
        @builder.ol_item(buf, num)
      end
      @builder.ol_end
    end

    def compile_dlist(f)
      if should_use_ast?(:dlist)
        build_dlist_ast(f)
      else
        compile_dlist_traditional(f)
      end
    end

    def compile_dlist_traditional(f)
      @builder.dl_begin
      while /\A\s*:/ =~ f.peek
        # defer compile_inline to handle footnotes
        @builder.doc_status[:dt] = true
        @builder.dt(text(f.gets.sub(/\A\s*:/, '').strip))
        @builder.doc_status[:dt] = nil
        desc = []
        f.until_match(/\A(\S|\s*:|\s+\d+\.\s|\s+\*\s)/) do |line|
          desc << text(line.strip)
        end
        @builder.dd(desc)
        f.skip_blank_lines
        f.skip_comment_lines
      end
      @builder.dl_end
    end

    def compile_paragraph(f)
      if should_use_ast?(:paragraph)
        # For AST processing, collect raw lines without processing inline elements
        raw_lines = []
        f.until_match(%r{\A//|\A\#@}) do |line|
          break if line.strip.empty?

          raw_lines.push(line.sub(/^(\t+)\s*/) { |m| '<!ESCAPETAB!>' * m.size }.strip.gsub('<!ESCAPETAB!>', "\t"))
        end
        build_paragraph_ast(raw_lines)
      else
        # Traditional processing with inline elements processed immediately
        buf = []
        f.until_match(%r{\A//|\A\#@}) do |line|
          break if line.strip.empty?

          buf.push(text(line.sub(/^(\t+)\s*/) { |m| '<!ESCAPETAB!>' * m.size }.strip.gsub('<!ESCAPETAB!>', "\t")))
        end
        @builder.paragraph(buf)
      end
    end

    def read_command(f)
      line = f.gets
      name = line.slice(/[a-z]+/).to_sym
      ignore_inline = @non_parsed_commands.include?(name)
      @command_name_stack.push(name)
      args = parse_args(line.sub(%r{\A//[a-z]+}, '').rstrip.chomp('{'), name)
      @builder.doc_status[name] = true
      lines = block_open?(line) ? read_block(f, ignore_inline) : nil
      @builder.doc_status[name] = nil
      [name, args, lines]
    end

    def block_open?(line)
      line.rstrip[-1, 1] == '{'
    end

    def read_block(f, ignore_inline)
      head = f.lineno
      buf = []
      f.until_match(%r{\A//\}}) do |line|
        if ignore_inline
          buf.push(line.chomp)
        elsif !/\A\#@/.match?(line)
          buf.push(text(line.rstrip, true))
        end
      end
      unless f.peek.to_s.start_with?('//}')
        error "unexpected EOF (block begins at: #{head})", location: location
        return buf
      end
      f.gets # discard terminator
      buf
    end

    def parse_args(str, _name = nil)
      return [] if str.empty?

      scanner = StringScanner.new(str)
      words = []
      while word = scanner.scan(/(\[\]|\[.*?[^\\]\])/)
        w2 = word[1..-2].gsub(/\\(.)/) do
          ch = $1
          [']', '\\'].include?(ch) ? ch : '\\' + ch
        end
        words << w2
      end
      unless scanner.eos?
        error "argument syntax error: #{scanner.rest} in #{str.inspect}", location: location
        return []
      end
      words
    end

    def compile_command(syntax, args, lines)
      unless @builder.respond_to?(syntax.name)
        error "builder does not support command: //#{syntax.name}", location: location
        return
      end
      begin
        syntax.check_args(args)
      rescue CompileError => e
        error e.message, location: location
        args = ['(NoArgument)'] * syntax.min_argc
      end

      # Check if this command should be processed via AST
      if should_use_ast?(syntax.name)
        build_block_command_ast(syntax.name, args, lines)
      elsif syntax.block_allowed?
        compile_block(syntax, args, lines)
      else
        if lines
          error "block is not allowed for command //#{syntax.name}; ignore", location: location
        end
        compile_single(syntax, args)
      end
    end

    def compile_block(syntax, args, lines)
      @builder.__send__(syntax.name, lines || default_block(syntax), *args)
    end

    def default_block(syntax)
      if syntax.block_required?
        error "block is required for //#{syntax.name}; use empty block", location: location
      end
      []
    end

    def compile_single(syntax, args)
      @builder.__send__(syntax.name, *args)
    end

    def replace_fence(str)
      str.gsub(/@<(\w+)>([$|])(.+?)(\2)/) do
        op = $1
        arg = $3
        if /[\x01\x02\x03\x04]/.match?(arg)
          error "invalid character in '#{str}'", location: location
        end
        replaced = arg.tr('@', "\x01").tr('\\', "\x02").tr('{', "\x03").tr('}', "\x04")
        "@<#{op}>{#{replaced}}"
      end
    end

    def revert_replace_fence(str)
      str.tr("\x01", '@').tr("\x02", '\\').tr("\x03", '{').tr("\x04", '}')
    end

    def in_non_escaped_command?
      current_command = @command_name_stack.last
      current_command && non_escaped_commands.include?(current_command)
    end

    def text(str, block_mode = false)
      return '' if str.empty?

      words = replace_fence(str).split(/(@<\w+>\{(?:[^}\\]|\\.)*?\})/, -1)
      words.each do |w|
        if w.scan(/@<\w+>/).size > 1 && !/\A@<raw>/.match(w)
          error "`@<xxx>' seen but is not valid inline op: #{w}", location: location
        end
      end
      result = +''
      until words.empty?
        result << if in_non_escaped_command? && block_mode
                    revert_replace_fence(words.shift)
                  else
                    @builder.nofunc_text(revert_replace_fence(words.shift))
                  end
        break if words.empty?

        result << compile_inline(revert_replace_fence(words.shift.gsub('\\}', '}').gsub('\\\\', '\\')))
      end
      result
    rescue StandardError => e
      error e.message, location: location
    end
    public :text # called from builder

    def compile_inline(str)
      op, arg = /\A@<(\w+)>\{(.*?)\}\z/.match(str).captures
      unless inline_defined?(op)
        raise CompileError, "no such inline op: #{op}"
      end
      unless @builder.respond_to?("inline_#{op}")
        raise "builder does not support inline op: @<#{op}>"
      end

      @builder.__send__("inline_#{op}", arg)
    rescue StandardError => e
      error e.message, location: location
      @builder.nofunc_text(str)
    end

    def in_minicolumn?
      @builder.in_minicolumn?
    end

    def minicolumn_block_name?(name)
      @builder.minicolumn_block_name?(name)
    end

    def ignore_errors?
      @ignore_errors
    end

    def location
      @builder.location.snapshot
    end

    ## override
    def error(msg, location: nil)
      return if ignore_errors? # for IndexBuilder

      @compile_errors = true
      super
    end
  end
end # module ReVIEW
