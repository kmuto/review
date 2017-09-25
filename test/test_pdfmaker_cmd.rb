require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'rbconfig'

REVIEW_PDFMAKER = File.expand_path('../bin/review-pdfmaker', File.dirname(__FILE__))

class PDFMakerCmdTest < Test::Unit::TestCase
  def setup
    @tmpdir1 = Dir.mktmpdir

    @old_rubylib = ENV['RUBYLIB']
    ENV['RUBYLIB'] = File.expand_path('../lib', File.dirname(__FILE__))
  end

  def teardown
    FileUtils.rm_rf @tmpdir1
    ENV['RUBYLIB'] = @old_rubylib
  end

  def test_pdfmaker_cmd
    if /mswin|mingw|cygwin/ !~ RUBY_PLATFORM
      config = prepare_samplebook(@tmpdir1)
      builddir = @tmpdir1 + '/' + config['bookname'] + '-pdf'
      assert !File.exist?(builddir)

      ruby_cmd = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
      Dir.chdir(@tmpdir1) do
        system("#{ruby_cmd} -S #{REVIEW_PDFMAKER} config.yml 1>/dev/null 2>/dev/null")
      end

      assert File.exist?(builddir)
    end
  end
end
