require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'rbconfig'
require 'open3'

REVIEW_IDGXMLMAKER = File.expand_path('../bin/review-idgxmlmaker', __dir__)

class IDGXMLMakerCmdTest < Test::Unit::TestCase
  def setup
    @tmpdir1 = Dir.mktmpdir

    @old_rubylib = ENV['RUBYLIB']
    ENV['RUBYLIB'] = File.expand_path('../lib', __dir__)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir1)
    ENV['RUBYLIB'] = @old_rubylib
  end

  def common_buildidgxml(bookdir, configfile, targetfile, option)
    if /mswin|mingw|cygwin/ !~ RUBY_PLATFORM
      config = prepare_samplebook(@tmpdir1, bookdir, nil, configfile)
      builddir = File.join(@tmpdir1, config['bookname'] + '-idgxml')
      assert !File.exist?(builddir)

      ruby_cmd = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name']) + RbConfig::CONFIG['EXEEXT']
      Dir.chdir(@tmpdir1) do
        _o, e, s = Open3.capture3("#{ruby_cmd} -S #{REVIEW_IDGXMLMAKER} #{option} #{configfile}")
        if defined?(ReVIEW::TTYLogger)
          assert_match(/SUCCESS/, e)
        else
          assert_equal '', e
        end
        assert s.success?
      end
      assert File.exist?(File.join(@tmpdir1, targetfile))
    end
  end

  def test_idgxmlmaker_cmd_samplebook
    common_buildidgxml('sample-book/src', 'config.yml', 'book-idgxml/ch01.xml', nil)
  end

  def test_idgxmlmaker_cmd_syntaxbook
    common_buildidgxml('syntax-book', 'config.yml', 'syntax-book-idgxml/ch01.xml', nil)
  end
end
