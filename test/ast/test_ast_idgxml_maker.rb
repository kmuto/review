# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'fileutils'
require 'review/ast/command/idgxml_maker'

class ASTIdgxmlMakerTest < Test::Unit::TestCase
  def setup
    @tmpdir = Dir.mktmpdir
    @old_pwd = Dir.pwd
  end

  def teardown
    Dir.chdir(@old_pwd)
    FileUtils.rm_rf(@tmpdir)
  end

  def test_builds_sample_book_with_renderer
    if /mswin|mingw|cygwin/.match?(RUBY_PLATFORM)
      omit('IDGXML build is not supported on Windows CI')
    end

    config = prepare_samplebook(@tmpdir, 'sample-book/src', nil, 'config.yml')
    output_dir = File.join(@tmpdir, "#{config['bookname']}-idgxml")
    target_file = File.join(output_dir, 'ch01.xml')

    Dir.chdir(@tmpdir) do
      maker = ReVIEW::AST::Command::IdgxmlMaker.new
      maker.execute('config.yml')
    end

    assert(File.exist?(target_file), 'Expected IDGXML output file to be generated')

    content = File.read(target_file)
    assert_includes(content, '<doc xmlns:aid="http://ns.adobe.com/AdobeInDesign/4.0/">')
  end
end
