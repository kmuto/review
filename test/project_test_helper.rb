# frozen_string_literal: true

require 'English'
require_relative 'test_helper'
require 'fileutils'

class ProjectTestHelper
  def self.project_dir
    File.join(File.dirname(__FILE__), '..', 'fixtures', 'integration')
  end

  def self.config_file
    File.join(project_dir, 'config.yml')
  end

  def self.catalog_file
    File.join(project_dir, 'catalog.yml')
  end

  def self.setup_test_environment
    # Ensure project directory exists
    unless Dir.exist?(project_dir)
      raise "Test project directory not found: #{project_dir}"
    end

    # Verify required files exist
    required_files = %w[config.yml catalog.yml]
    required_files.each do |file|
      file_path = File.join(project_dir, file)
      unless File.exist?(file_path)
        raise "Required file not found: #{file_path}"
      end
    end
  end

  def self.compile_traditional(target_format, debug: false)
    setup_test_environment

    old_dir = Dir.pwd
    begin
      Dir.chdir(project_dir)

      # Run traditional review-compile
      review_root = File.expand_path('..', File.dirname(__FILE__))
      cmd = "bundle exec #{File.join(review_root, 'bin', 'review-compile')} --target=#{target_format}"

      puts "DEBUG: Running traditional command: #{cmd}" if debug
      result = case target_format
               when 'html', 'latex'
                 `#{cmd} basic_elements.re 2>&1`
               else
                 `#{cmd} comprehensive_test.re 2>&1`
               end

      if debug && !$CHILD_STATUS.success?
        puts "DEBUG: Traditional command failed with exit code: #{$CHILD_STATUS.exitstatus}"
        puts "DEBUG: Command output: #{result}"
        puts "DEBUG: Working directory: #{Dir.pwd}"
        puts "DEBUG: Basic elements file exists: #{File.exist?('basic_elements.re')}"
      end

      {
        success: $CHILD_STATUS.success?,
        output: result,
        exit_code: $CHILD_STATUS.exitstatus
      }
    ensure
      Dir.chdir(old_dir)
    end
  end

  def self.compile_ast_renderer(target_format, debug: false)
    setup_test_environment

    old_dir = Dir.pwd
    begin
      Dir.chdir(project_dir)

      # Run AST/Renderer review-ast-compile
      review_root = File.expand_path('..', File.dirname(__FILE__))
      cmd = "bundle exec #{File.join(review_root, 'bin', 'review-ast-compile')} --target=#{target_format}"

      puts "DEBUG: Running AST/Renderer command: #{cmd}" if debug
      result = case target_format
               when 'html'
                 `#{cmd} basic_elements.re 2>&1`
               else
                 `#{cmd} comprehensive_test.re 2>&1`
               end

      if debug && !$CHILD_STATUS.success?
        puts "DEBUG: AST/Renderer command failed with exit code: #{$CHILD_STATUS.exitstatus}"
        puts "DEBUG: Command output: #{result}"
        puts "DEBUG: Working directory: #{Dir.pwd}"
        puts "DEBUG: Basic elements file exists: #{File.exist?('basic_elements.re')}"
      end

      {
        success: $CHILD_STATUS.success?,
        output: result,
        exit_code: $CHILD_STATUS.exitstatus
      }
    ensure
      Dir.chdir(old_dir)
    end
  end

  def self.test_all_formats_traditional
    results = {}
    %w[html latex].each do |format|
      results[format] = compile_traditional(format)
    end
    results
  end

  def self.test_all_formats_ast_renderer
    results = {}
    %w[html].each do |format| # Start with HTML, add LaTeX when ready
      results[format] = compile_ast_renderer(format)
    end
    results
  end

  def self.test_cross_references_traditional
    compile_traditional('html')
  end

  def self.test_cross_references_ast_renderer
    compile_ast_renderer('html')
  end

  def self.verify_project_structure
    {
      config_exists: File.exist?(config_file),
      catalog_exists: File.exist?(catalog_file),
      images_dir: Dir.exist?(File.join(project_dir, 'images')),
      sty_dir: Dir.exist?(File.join(project_dir, 'sty')),
      re_files: Dir.glob(File.join(project_dir, '*.re')).map { |f| File.basename(f) }
    }
  end

  def self.available_re_files
    Dir.glob(File.join(project_dir, '*.re')).map { |f| File.basename(f) }.sort
  end
end
