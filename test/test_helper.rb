$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib/')
require 'test/unit'

def touch_file(path)
  File.open(path, 'w').close
  path
end

def assets_dir
  File.join(File.dirname(__FILE__), 'assets')
end

def prepare_samplebook(srcdir)
  samplebook_dir = File.expand_path('sample-book/src/', File.dirname(__FILE__))
  FileUtils.cp_r(Dir.glob(samplebook_dir + '/*'), srcdir)
  YAML.load(File.open(srcdir + '/config.yml'))
end

def compile_inline(text)
  @builder.compile_inline(text)
end

def compile_block(text)
  method_name = "compile_block_#{@builder.target_name}"
  method_name = 'compile_block_default' unless self.respond_to?(method_name, true)
  self.__send__(method_name, text)
end

def compile_block_default(text)
  @chapter.content = text
  @compiler.compile(@chapter)
end

def compile_block_html(text)
  @chapter.content = text
  matched = @compiler.compile(@chapter).match(Regexp.new(%Q(<body>\n(.+)</body>), Regexp::MULTILINE))
  if matched && matched.size > 1
    matched[1]
  else
    ''
  end
end

def compile_block_idgxml(text)
  @chapter.content = text
  @compiler.compile(@chapter).gsub(Regexp.new(%Q(.*<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/">), Regexp::MULTILINE), '').gsub("</doc>\n", '')
end
