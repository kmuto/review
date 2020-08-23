# Copyright (c) 2008-2020 Minero Aoki, Kenshi Muto, Masayoshi Takahashi,
#                         KADO Masanori
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

require 'review/book/index'
require 'review/exception'
require 'review/builder'
require 'review/sec_counter'

module ReVIEW
  class IndexBuilder < Builder
    CAPTION_TITLES = %w[note memo tip info warning important caution notice box].freeze

    attr_reader :list_index, :table_index, :equation_index, :footnote_index,
                :numberless_image_index, :image_index, :icon_index, :indepimage_index,
                :headline_index, :column_index, :bibpaper_index

    def initialize(strict = false, *args)
      super
    end

    def pre_paragraph
      ''
    end

    def post_paragraph
      ''
    end

    def bind(compiler, chapter, location)
      @compiler = compiler
      @chapter = chapter
      @location = location
      if @chapter.present?
        @book = @chapter.book
      end
      builder_init_file
    end

    def builder_init_file
      @sec_counter = SecCounter.new(5, @chapter)

      @headline_stack = []

      @list_index = ReVIEW::Book::ListIndex.new
      @table_index = ReVIEW::Book::TableIndex.new
      @equation_index = ReVIEW::Book::EquationIndex.new
      @footnote_index = ReVIEW::Book::FootnoteIndex.new
      @headline_index = ReVIEW::Book::HeadlineIndex.new(@chapter)
      @column_index = ReVIEW::Book::ColumnIndex.new
      @chapter_index = ReVIEW::Book::ChapterIndex.new
      @bibpaper_index = ReVIEW::Book::BibpaperIndex.new

      if @book
        @image_index = ReVIEW::Book::ImageIndex.new(@chapter.name,
                                                    @book.imagedir,
                                                    @book.image_types, @book.config['builder'])
        @icon_index = ReVIEW::Book::IconIndex.new(@chapter.name,
                                                  @book.imagedir,
                                                  @book.image_types, @book.config['builder'])
        @numberless_image_index = ReVIEW::Book::NumberlessImageIndex.new(@chapter.name,
                                                                         @book.imagedir,
                                                                         @book.image_types, @book.config['builder'])
        @indepimage_index = ReVIEW::Book::IndepImageIndex.new(@chapter.name,
                                                              @book.imagedir,
                                                              @book.image_types, @book.config['builder'])
      end
    end
    private :builder_init_file

    def result
      nil
    end

    def target_name
      'index'
    end

    def headline(level, label, caption)
      @sec_counter.inc(level)
      return if level < 2

      cursor = level - 2

      if label
        @headline_stack[cursor] = label
      else
        @headline_stack[cursor] = caption
      end
      if @headline_stack.size > cursor + 1
        @headline_stack = @headline_stack.take(cursor + 1)
      end

      item_id = @headline_stack.join('|')

      item = ReVIEW::Book::Index::Item.new(item_id, @sec_counter.number_list, caption)
      @headline_index.add_item(item)
    end

    def nonum_begin(level, label, caption)
      cursor = level - 2

      if label
        @headline_stack[cursor] = label
      else
        @headline_stack[cursor] = caption
      end
      if @headline_stack.size > cursor + 1
        @headline_stack = @headline_stack.take(cursor + 1)
      end

      item_id = @headline_stack.join('|')

      item = ReVIEW::Book::Index::Item.new(item_id, nil, caption)
      @headline_index.add_item(item)
    end

    def nonum_end(_level)
    end

    def notoc_begin(level, label, caption)
      cursor = level - 2

      if label
        @headline_stack[cursor] = label
      else
        @headline_stack[cursor] = caption
      end
      if @headline_stack.size > cursor + 1
        @headline_stack = @headline_stack.take(cursor + 1)
      end

      item_id = @headline_stack.join('|')

      item = ReVIEW::Book::Index::Item.new(item_id, nil, caption)
      @headline_index.add_item(item)
    end

    def notoc_end(_level)
    end

    def nodisp_begin(level, label, caption)
      cursor = level - 2

      if label
        @headline_stack[cursor] = label
      else
        @headline_stack[cursor] = caption
      end
      if @headline_stack.size > cursor + 1
        @headline_stack = @headline_stack.take(cursor + 1)
      end

      item_id = @headline_stack.join('|')

      item = ReVIEW::Book::Index::Item.new(item_id, nil, caption)
      @headline_index.add_item(item)
    end

    def nodisp_end(_level)
    end

    def column_begin(_level, label, caption)
      item_id = label || caption
      item = ReVIEW::Book::Index::Item.new(item_id, @column_index.size + 1, caption)
      @column_index.add_item(item)
    end

    def column_end(_level)
    end

    def xcolumn_begin(level, label, caption)
    end

    def xcolumn_end(_level)
    end

    def sup_begin(level, label, caption)
    end

    def sup_end(_level)
    end

    def ul_begin
    end

    def ul_item_begin(lines)
    end

    def ul_item_end
    end

    def ul_end
    end

    def ol_begin
    end

    def ol_item(lines, _num)
    end

    def ol_end
    end

    def dl_begin
    end

    def dt(line)
    end

    def dd(lines)
    end

    def dl_end
    end

    def paragraph(lines)
    end

    def parasep
      ''
    end

    def nofunc_text(_str)
      ''
    end

    def read(_lines)
    end

    alias_method :lead, :read

    def list(_lines, id, _caption, _lang = nil)
      item = ReVIEW::Book::Index::Item.new(id, @list_index.size + 1)
      @list_index.add_item(item)
    end

    def source(_lines, _caption = nil, _lang = nil)
    end

    def listnum(_lines, id, _caption, _lang = nil)
      item = ReVIEW::Book::Index::Item.new(id, @list_index.size + 1)
      @list_index.add_item(item)
    end

    def emlist(lines, caption = nil, lang = nil)
    end

    def emlistnum(lines, caption = nil, lang = nil)
    end

    def cmd(lines, caption = nil)
    end

    def quote(lines)
    end

    def image(_lines, id, caption, _metric = nil)
      item = ReVIEW::Book::Index::Item.new(id, @image_index.size + 1, caption)
      @image_index.add_item(item)
    end

    def table(_lines, id = nil, caption = nil)
      if id
        item = ReVIEW::Book::Index::Item.new(id, @table_index.size + 1, caption)
        @table_index.add_item(item)
      end
    end

    def emtable(_lines, _caption = nil)
      # item = ReVIEW::Book::TableIndex::Item.new(id, @table_index.size + 1)
      # @table_index << item
    end

    def comment(lines, comment = nil)
    end

    def imgtable(_lines, id, _caption = nil, _metric = nil)
      item = ReVIEW::Book::Index::Item.new(id, @table_index.size + 1)
      @table_index.add_item(item)

      ## to find image path
      item = ReVIEW::Book::Index::Item.new(id, @indepimage_index.size + 1)
      @indepimage_index.add_item(item)
    end

    def footnote(id, str)
      item = ReVIEW::Book::Index::Item.new(id, @footnote_index.size + 1, str)
      @footnote_index.add_item(item)
    end

    def indepimage(_lines, id, _caption = '', _metric = nil)
      item = ReVIEW::Book::Index::Item.new(id, @indepimage_index.size + 1)
      @indepimage_index.add_item(item)
    end

    def numberlessimage(_lines, id, _caption = '', _metric = nil)
      item = ReVIEW::Book::Index::Item.new(id, @indepimage_index.size + 1)
      @indepimage_index.add_item(item)
    end

    def hr
    end

    def label(_id)
    end

    def blankline
    end

    def flushright(_lines)
    end

    def centering(lines)
    end

    def olnum(_num)
    end

    def pagebreak
    end

    def bpo(_lines)
    end

    def noindent
    end

    def compile_inline(s)
      @compiler.text(s)
    end

    def inline_chapref(_id)
      ''
    end

    def inline_chap(_id)
      ''
    end

    def inline_title(_id)
      ''
    end

    def inline_list(_id)
      ''
    end

    def inline_img(_id)
      ''
    end

    def inline_imgref(_id)
      ''
    end

    def inline_table(_id)
      ''
    end

    def inline_eq(_id)
      ''
    end

    def inline_fn(_id)
      ''
    end

    def inline_i(_str)
      ''
    end

    def inline_b(_str)
      ''
    end

    def inline_ami(_str)
      ''
    end

    def inline_bou(str)
      str
    end

    def inline_tti(_str)
      ''
    end

    def inline_ttb(_str)
      ''
    end

    def inline_dtp(_str)
      ''
    end

    def inline_code(_str)
      ''
    end

    def inline_idx(_str)
      ''
    end

    def inline_hidx(_str)
      ''
    end

    def inline_br(_str)
      ''
    end

    def inline_m(_str)
      ''
    end

    def firstlinenum(_num)
      ''
    end

    def inline_ruby(_arg)
      ''
    end

    def inline_kw(_arg)
      ''
    end

    def inline_href(_arg)
      ''
    end

    def inline_hr(_arg)
      ''
    end

    def text(_str)
      ''
    end

    def bibpaper(_lines, id, caption)
      item = ReVIEW::Book::Index::Item.new(id, @bibpaper_index.size + 1, caption)
      @bibpaper_index.add_item(item)
    end

    def inline_hd(_id)
      ''
    end

    def inline_bib(_id)
      ''
    end

    def inline_column(_id)
      ''
    end

    def inline_column_chap(_chapter, _id)
      ''
    end

    def inline_pageref(_id)
      ''
    end

    def inline_tcy(_arg)
      ''
    end

    def inline_balloon(_arg)
      ''
    end

    def inline_w(_s)
      ''
    end

    def inline_wb(_s)
      ''
    end

    def inline_abbr(_str)
      ''
    end

    def inline_acronym(_str)
      ''
    end

    def inline_cite(_str)
      ''
    end

    def inline_dfn(_str)
      ''
    end

    def inline_em(_str)
      ''
    end

    def inline_kbd(_str)
      ''
    end

    def inline_samp(_str)
      ''
    end

    def inline_strong(_str)
      ''
    end

    def inline_var(_str)
      ''
    end

    def inline_big(_str)
      ''
    end

    def inline_small(_str)
      ''
    end

    def inline_sub(_str)
      ''
    end

    def inline_sup(_str)
      ''
    end

    def inline_tt(_str)
      ''
    end

    def inline_del(_str)
      ''
    end

    def inline_ins(_str)
      ''
    end

    def inline_u(_str)
      ''
    end

    def inline_recipe(_str)
      ''
    end

    def inline_icon(id)
      item = ReVIEW::Book::Index::Item.new(id, @icon_index.size + 1)
      @icon_index.add_item(item)
      ''
    end

    def inline_uchar(_str)
      ''
    end

    def raw(_str)
      ''
    end

    def embed(_lines, _arg = nil)
      ''
    end

    def warn(msg)
      @logger.warn "#{@location}: #{msg}"
    end

    def error(msg = '(no message)')
      if msg =~ /builder does not support command/
        # ignore
        return
      end
      super
    end

    def texequation(_lines, id = nil, _caption = '')
      if id
        item = ReVIEW::Book::Index::Item.new(id, @equation_index.size + 1)
        @equation_index.add_item(item)
      end
    end

    def get_chap(_chapter = nil)
      ''
    end

    def extract_chapter_id(_chap_ref)
      ''
    end

    def captionblock(_type, _lines, _caption, _specialstyle = nil)
      ''
    end

    CAPTION_TITLES.each do |name|
      class_eval %Q(
        def #{name}(lines, caption = nil)
          captionblock("#{name}", lines, caption)
        end
      ), __FILE__, __LINE__ - 4
    end

    def tsize(_str)
      ''
    end

    def inline_raw(_args)
      ''
    end

    def inline_embed(_args)
      ''
    end

    def highlight?
      false
    end

    def unknown_command(*_args)
      # ignore
    end
  end
end # module ReVIEW
