$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib/')
require 'test/unit'

  def compile_block(str, force_to_s=true)
    @compiler.setup_parser(str)
    @compiler.tagged_section_init
    @compiler.parse("Block")
    if force_to_s
      @compiler.result.to_s
    else
      @compiler.result
    end
  end

  def compile_inline(str, force_to_s=true)
    @compiler.setup_parser(str)
    @compiler.tagged_section_init
    @compiler.parse("Paragraph")
    if force_to_s
      @compiler.result.map(&:to_s).join
    else
      @compiler.result
    end
  end

  def compile_blockelem(str, force_to_s=true)
    @compiler.setup_parser(str)
    @compiler.tagged_section_init
    @compiler.parse("BlockElement")
    if force_to_s
      @compiler.result.to_s
    else
      @compiler.result
    end
  end

  def compile_headline(str)
    @compiler.setup_parser(str)
    @compiler.tagged_section_init
    @compiler.parse("Headline")
    @compiler.result.to_s
  end

def ul_helper(src, expect)
  @compiler.setup_parser(src)
  @compiler.tagged_section_init
  @compiler.parse("Ulist")
  assert_equal expect, @compiler.result.to_s
end

def ol_helper(src, expect)
  @compiler.setup_parser(src)
  @compiler.tagged_section_init
  @compiler.parse("Olist")
  assert_equal expect, @compiler.result.to_s
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
