require 'test_helper'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require 'rbconfig'
require 'open3'

REVIEW_PDFMAKER = File.expand_path('../bin/review-pdfmaker', __dir__)

class PDFMakerCmdTest < Test::Unit::TestCase
  def setup
    @tmpdir1 = Dir.mktmpdir

    @old_rubylib = ENV['RUBYLIB']
    ENV['RUBYLIB'] = File.expand_path('../lib', __dir__)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir1)
    ENV['RUBYLIB'] = @old_rubylib
  end

  def common_buildpdf(bookdir, templatedir, configfile, targetpdffile, option = nil)
    unless /mswin|mingw|cygwin/.match?(RUBY_PLATFORM)
      config = prepare_samplebook(@tmpdir1, bookdir, templatedir, configfile)
      builddir = File.join(@tmpdir1, config['bookname'] + '-pdf')
      assert !File.exist?(builddir)

      ruby_cmd = File.join(RbConfig::CONFIG['bindir'], RbConfig::CONFIG['ruby_install_name'])
      Dir.chdir(@tmpdir1) do
        _o, e, s = Open3.capture3("#{ruby_cmd} -S #{REVIEW_PDFMAKER} #{option} #{configfile}")
        if !e.empty? && !s.success?
          $stderr.puts e
        end
        assert s.success?
      end
      assert File.exist?(File.join(@tmpdir1, targetpdffile))
    end
  end

  def test_pdfmaker_cmd_sample_jsbook_print
    begin
      `uplatex -v`
    rescue StandardError
      $stderr.puts 'skip test_pdfmaker_cmd_sample_jsbook_print'
      return true
    end
    common_buildpdf('sample-book/src', 'review-jsbook', 'config.yml', 'book.pdf')
  end

  def test_pdfmaker_cmd_sample_jsbook_ebook
    begin
      `uplatex -v`
    rescue StandardError
      $stderr.puts 'skip test_pdfmaker_cmd_sample_jsbook_ebook'
      return true
    end
    common_buildpdf('sample-book/src', 'review-jsbook', 'config-ebook.yml', 'book.pdf')
  end

  def test_pdfmaker_cmd_sample_jlreq_print
    begin
      `uplatex -v`
    rescue StandardError
      $stderr.puts 'skip test_pdfmaker_cmd_sample_jlreq_print'
      return true
    end
    common_buildpdf('sample-book/src', 'review-jlreq', 'config-jlreq.yml', 'book.pdf')
  end

  def test_pdfmaker_cmd_sample_jlreq_ebook
    begin
      `uplatex -v`
    rescue StandardError
      $stderr.puts 'skip test_pdfmaker_cmd_sample_jlreq_ebook'
      return true
    end
    common_buildpdf('sample-book/src', 'review-jlreq', 'config-jlreq-ebook.yml', 'book.pdf')
  end

  def test_pdfmaker_cmd_syntax_jsbook_print
    begin
      `uplatex -v`
    rescue StandardError
      $stderr.puts 'skip test_pdfmaker_cmd_syntax_jsbook_print'
      return true
    end
    common_buildpdf('syntax-book', 'review-jsbook', 'config-print.yml', 'syntax-book.pdf')
  end

  def test_pdfmaker_cmd_syntax_jsbook_print_buildonly
    begin
      `uplatex -v`
    rescue StandardError
      $stderr.puts 'skip test_pdfmaker_cmd_syntax_jsbook_print_buildonly'
      return true
    end
    common_buildpdf('syntax-book', 'review-jsbook', 'config-print.yml', 'syntax-book.pdf', '-y ch01')
  end

  def test_pdfmaker_cmd_syntax_jsbook_ebook
    begin
      `uplatex -v`
    rescue StandardError
      $stderr.puts 'skip test_pdfmaker_cmd_syntax_jsbook_ebook'
      return true
    end
    common_buildpdf('syntax-book', 'review-jsbook', 'config.yml', 'syntax-book.pdf')
  end

  def test_pdfmaker_cmd_syntax_jlreq_ebook
    begin
      `uplatex -v`
    rescue StandardError
      $stderr.puts 'skip test_pdfmaker_cmd_syntax_jlreq_ebook'
      return true
    end
    common_buildpdf('syntax-book', 'review-jlreq', 'config-jlreq.yml', 'syntax-book.pdf')
  end

  def test_pdfmaker_cmd_syntax_jlreq_ebook_lualatex
    begin
      `lualatex -v`
    rescue StandardError
      $stderr.puts 'skip test_pdfmaker_cmd_syntax_jlreq_ebook_lualatex'
      return true
    end
    common_buildpdf('syntax-book', 'review-jlreq', 'config-jlreq-lualatex.yml', 'syntax-book.pdf')
  end
end
