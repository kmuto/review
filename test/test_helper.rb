$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib/')
require 'test/unit'

  def compile_document(str, force_to_s=true)
    @compiler.setup_parser(str)
    @compiler.parse("Document")
    if force_to_s
      @compiler.result.to_doc
    else
      @compiler.result
    end
  end

  def compile_inline(str, force_to_s=true)
    @compiler.setup_parser(str)
    @compiler.parse("Paragraph")
    if force_to_s
##      @compiler.result.map(&:to_doc).join
      @compiler.result.to_doc
    else
      @compiler.result
    end
  end

  def compile_blockelem(str, force_to_s=true)
    @compiler.setup_parser(str)
    @compiler.parse("BlockElement")
    if force_to_s
      @compiler.result.to_doc
    else
      @compiler.result
    end
  end

  def compile_headline(str)
    @compiler.setup_parser(str)
    @compiler.parse("Headline")
    @compiler.result.to_doc
  end

def touch_file(path)
  File.open(path, "w").close
  path
end

def assets_dir
  File.join(File.dirname(__FILE__), "assets")
end

def prepare_samplebook(srcdir)
  samplebook_dir = File.expand_path("sample-book/src/", File.dirname(__FILE__))
  FileUtils.cp_r(Dir.glob(samplebook_dir + "/*"), srcdir)
  YAML.load(File.open(srcdir + "/config.yml"))
end

def compile_block(text)
  method_name = "compile_block_#{@builder.target_name}"
  if !self.respond_to?(method_name, true)
    method_name = "compile_block_default"
  end
  self.__send__(method_name, text)
end

def compile_block_default(text)
  @chapter.content = text
  @compiler.compile(@chapter)
end

def compile_block_html(text)
  @chapter.content = text
  matched = @compiler.compile(@chapter).match(/<body>\n(.+)<\/body>/m)
  if matched && matched.size > 1
    matched[1]
  else
    ""
  end
end

def compile_block_idgxml(text)
  @chapter.content = text
  @compiler.compile(@chapter).gsub(/.*<doc xmlns:aid="http:\/\/ns.adobe.com\/AdobeInDesign\/4.0\/">/m,"").gsub(/<\/doc>\n/, "")
end
