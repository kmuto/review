$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib/')
require 'test/unit'

def ul_helper(src, expect)
  io = StringIO.new(src)
  li = LineInput.new(io)
  @compiler.__send__(:compile_ulist, li)
  assert_equal expect, @builder.raw_result
end

def builder_helper(src, expect, method_sym)
  io = StringIO.new(src)
  li = LineInput.new(io)
  @compiler.__send__(method_sym, li)
  assert_equal expect, @builder.raw_result
end
