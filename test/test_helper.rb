$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib/')
require 'test/unit'

def ul_helper(src, expect)
  io = StringIO.new(src)
  li = LineInput.new(io)
  @compiler.__send__(:compile_ulist, li)
  assert_equal expect, @builder.raw_result
end

def ol_helper(src, expect)
  io = StringIO.new(src)
  li = LineInput.new(io)
  @compiler.__send__(:compile_olist, li)
  assert_equal expect, @builder.raw_result
end

def builder_helper(src, expect, method_sym)
  io = StringIO.new(src)
  li = LineInput.new(io)
  @compiler.__send__(method_sym, li)
  assert_equal expect, @builder.raw_result
end

def touch_file(path)
  File.open(path, "w").close
  path
end

def prepare_samplebook(srcdir)
  samplebook_dir = File.expand_path("sample-book/src/", File.dirname(__FILE__))
  FileUtils.cp_r(Dir.glob(samplebook_dir + "/*"), srcdir)
  YAML.load(File.open(srcdir + "/config.yml"))
end

def compile_block(text)
  @chapter.content = text
  matched = @compiler.compile(@chapter).match(/<body>\n(.+)<\/body>/m)
  if matched && matched.size > 1
    matched[1]
  else
    ""
  end
end

def compile_inline(text)
  @builder.compile_inline(text)
end
