require 'test_helper'
require 'review/extentions/hash'

class TestExtentionsHash < Test::Unit::TestCase
  def test_deep_merge_simple
    assert_equal({ a: 1, b: 3, c: 4 },
                 { a: 1, b: 2 }.deep_merge(b: 3, c: 4))
  end

  def test_deep_empty_r
    assert_equal({ b: 3, c: 4 },
                 {}.deep_merge(b: 3, c: 4))
  end

  def test_deep_empty_l
    assert_equal({ a: 1, b: 2 },
                 { a: 1, b: 2 }.deep_merge({}))
  end

  def test_deep_merge_nested
    assert_equal({ a: { aa: 1, ab: 2 },
                   b: { ba: 5, bb: 4, bc: 6 },
                   c: { ca: 1 } },
                 { a: { aa: 1, ab: 2 },
                   b: { ba: 3, bb: 4 } }.deep_merge(b: { ba: 5, bc: 6 },
                                                    c: { ca: 1 }))
  end

  def test_deep_merge_with_array
    assert_equal({ a: 'string', b: ['BA'],
                   c: { ca: [cab: 'CAB'], cb: 3 } },
                 { a: 1, b: ['shouldoverriden'],
                   c: { ca: [caa: 'shouldoverriden'], cb: 3 } }.
                   deep_merge(a: 'string', b: ['BA'],
                              c: { ca: [cab: 'CAB'] }))
  end

  def test_deep_merge_b_simple
    a = { a: 1, b: 2 }
    a.deep_merge!(b: 3, c: 4)
    assert_equal({ a: 1, b: 3, c: 4 }, a)
  end

  def test_deep_b_empty_r
    a = {}
    a.deep_merge!(b: 3, c: 4)
    assert_equal({ b: 3, c: 4 }, a)
  end

  def test_deep_b_empty_l
    a = { a: 1, b: 2 }
    a.deep_merge!({})
    assert_equal({ a: 1, b: 2 }, a)
  end

  def test_deep_merge_b_nested
    a = { a: { aa: 1, ab: 2 },
          b: { ba: 3, bb: 4 } }
    a.deep_merge!(b: { ba: 5, bc: 6 },
                  c: { ca: 1 })
    assert_equal({ a: { aa: 1, ab:  2 },
                   b: { ba: 5, bb: 4, bc: 6 },
                   c: { ca: 1 } },
                 a)
  end
end
