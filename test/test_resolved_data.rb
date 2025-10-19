# frozen_string_literal: true

require_relative 'test_helper'
require 'review/ast/resolved_data'

class ResolvedDataTest < Test::Unit::TestCase
  def test_initialize
    data = ReVIEW::AST::ResolvedData.new(
      type: :image,
      chapter_number: '1',
      item_number: 2,
      chapter_id: 'chap01',
      item_id: 'img01'
    )

    assert_equal :image, data.type
    assert_equal '1', data.chapter_number
    assert_equal 2, data.item_number
    assert_equal 'chap01', data.chapter_id
    assert_equal 'img01', data.item_id
  end

  # NOTE: ResolvedData is now mutable for simplicity
  # This test is removed as the class is no longer frozen

  def test_cross_chapter?
    # With chapter_id, it's cross-chapter
    data_cross = ReVIEW::AST::ResolvedData.new(
      type: :image,
      chapter_id: 'chap02',
      item_id: 'img01'
    )
    assert_true(data_cross.cross_chapter?)

    # Without chapter_id, it's same-chapter
    data_same = ReVIEW::AST::ResolvedData.new(
      type: :image,
      item_id: 'img01'
    )
    assert_false(data_same.cross_chapter?)
  end

  def test_exists?
    # With item_number, the reference exists
    data_exists = ReVIEW::AST::ResolvedData.new(
      type: :image,
      item_number: 1,
      item_id: 'img01'
    )
    assert_true(data_exists.exists?)

    # Without item_number, the reference doesn't exist
    data_not_exists = ReVIEW::AST::ResolvedData.new(
      type: :image,
      item_id: 'img01'
    )
    assert_false(data_not_exists.exists?)
  end

  def test_equality
    data1 = ReVIEW::AST::ResolvedData.new(
      type: :image,
      chapter_number: '1',
      item_number: 2,
      item_id: 'img01'
    )

    data2 = ReVIEW::AST::ResolvedData.new(
      type: :image,
      chapter_number: '1',
      item_number: 2,
      item_id: 'img01'
    )

    data3 = ReVIEW::AST::ResolvedData.new(
      type: :table,
      chapter_number: '1',
      item_number: 2,
      item_id: 'img01'
    )

    assert_equal data1, data2
    assert_not_equal(data1, data3)
  end

  def test_factory_method_image
    data = ReVIEW::AST::ResolvedData.image(
      chapter_number: '1',
      item_number: 2,
      chapter_id: 'chap01',
      item_id: 'img01'
    )

    assert_equal :image, data.type
    assert_equal '1', data.chapter_number
    assert_equal 2, data.item_number
    assert_equal 'chap01', data.chapter_id
    assert_equal 'img01', data.item_id
  end

  def test_factory_method_table
    data = ReVIEW::AST::ResolvedData.table(
      chapter_number: '2',
      item_number: 3,
      item_id: 'tbl01'
    )

    assert_equal :table, data.type
    assert_equal '2', data.chapter_number
    assert_equal 3, data.item_number
    assert_equal 'tbl01', data.item_id
  end

  def test_factory_method_list
    data = ReVIEW::AST::ResolvedData.list(
      chapter_number: '3',
      item_number: 1,
      item_id: 'list01'
    )

    assert_equal :list, data.type
    assert_equal '3', data.chapter_number
    assert_equal 1, data.item_number
    assert_equal 'list01', data.item_id
  end

  def test_factory_method_equation
    data = ReVIEW::AST::ResolvedData.equation(
      chapter_number: '1',
      item_number: 5,
      item_id: 'eq01'
    )

    assert_equal :equation, data.type
    assert_equal '1', data.chapter_number
    assert_equal 5, data.item_number
    assert_equal 'eq01', data.item_id
  end

  def test_factory_method_footnote
    data = ReVIEW::AST::ResolvedData.footnote(
      item_number: 3,
      item_id: 'fn01'
    )

    assert_equal :footnote, data.type
    assert_equal 3, data.item_number
    assert_equal 'fn01', data.item_id
    assert_nil(data.chapter_number)
  end

  def test_factory_method_endnote
    data = ReVIEW::AST::ResolvedData.endnote(
      item_number: 2,
      item_id: 'endnote01'
    )

    assert_equal :endnote, data.type
    assert_equal 2, data.item_number
    assert_equal 'endnote01', data.item_id
  end

  def test_factory_method_chapter
    data = ReVIEW::AST::ResolvedData.chapter(
      chapter_number: '5',
      chapter_id: 'chap05',
      chapter_title: 'Advanced Topics'
    )

    assert_equal :chapter, data.type
    assert_equal '5', data.chapter_number
    assert_equal 'chap05', data.chapter_id
    assert_equal 'chap05', data.item_id
    assert_equal 'Advanced Topics', data.chapter_title
  end

  def test_factory_method_headline
    data = ReVIEW::AST::ResolvedData.headline(
      headline_number: [1, 2, 3],
      headline_caption: 'Installation Guide',
      chapter_id: 'chap01',
      item_id: 'hd123'
    )

    assert_equal :headline, data.type
    assert_equal [1, 2, 3], data.headline_number
    assert_equal 'Installation Guide', data.headline_caption
    assert_equal 'chap01', data.chapter_id
    assert_equal 'hd123', data.item_id
  end

  def test_factory_method_word
    data = ReVIEW::AST::ResolvedData.word(
      word_content: 'Ruby on Rails',
      item_id: 'rails'
    )

    assert_equal :word, data.type
    assert_equal 'Ruby on Rails', data.word_content
    assert_equal 'rails', data.item_id
  end

  def test_to_s
    data = ReVIEW::AST::ResolvedData.new(
      type: :image,
      chapter_number: '1',
      item_number: 2,
      chapter_id: 'chap01',
      item_id: 'img01'
    )

    str = data.to_s
    assert_match(/ResolvedData/, str)
    assert_match(/type=image/, str)
    assert_match(/chapter=1/, str)
    assert_match(/item=2/, str)
    assert_match(/chapter_id=chap01/, str)
    assert_match(/item_id=img01/, str)
  end

  def test_hash
    data1 = ReVIEW::AST::ResolvedData.new(
      type: :image,
      chapter_number: '1',
      item_number: 2,
      item_id: 'img01'
    )

    data2 = ReVIEW::AST::ResolvedData.new(
      type: :image,
      chapter_number: '1',
      item_number: 2,
      item_id: 'img01'
    )

    # Same data should have same hash
    assert_equal data1.hash, data2.hash

    # Can be used as hash key
    hash = {}
    hash[data1] = 'value1'
    hash[data2] = 'value2'
    assert_equal 1, hash.size
    assert_equal 'value2', hash[data1]
  end
end
