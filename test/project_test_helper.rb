# frozen_string_literal: true

require 'test_helper'
require 'fileutils'

class ProjectTestHelper
  def self.project_dir
    File.join(File.dirname(__FILE__), 'project')
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

  def self.compile_with_mode(target_format, ast_mode: 'auto', ast_stage: 7, debug: true)
    setup_test_environment
    
    old_dir = Dir.pwd
    begin
      Dir.chdir(project_dir)
      
      # Set environment variables for AST testing
      ENV['REVIEW_AST_MODE'] = ast_mode.to_s
      ENV['REVIEW_AST_STAGE'] = ast_stage.to_s
      ENV['REVIEW_DEBUG_AST'] = debug.to_s

      # Run compilation
      cmd = "bundle exec #{File.join('..', '..', 'bin', 'review-compile')} --yaml=config.yml --target=#{target_format}"
      
      case target_format
      when 'html'
        result = `#{cmd} basic_elements.re 2>&1`
      when 'latex'
        result = `#{cmd} basic_elements.re 2>&1`
      when 'json'
        result = `#{cmd} basic_elements.re 2>&1`
      else
        result = `#{cmd} comprehensive_test.re 2>&1`
      end
      
      {
        success: $?.success?,
        output: result,
        exit_code: $?.exitstatus
      }
    ensure
      Dir.chdir(old_dir)
      # Clean up environment variables
      ENV.delete('REVIEW_AST_MODE')
      ENV.delete('REVIEW_AST_STAGE') 
      ENV.delete('REVIEW_DEBUG_AST')
    end
  end

  def self.test_all_formats
    results = {}
    %w[html latex json].each do |format|
      results[format] = compile_with_mode(format)
    end
    results
  end

  def self.test_cross_references
    compile_with_mode('html', ast_mode: 'full', debug: true)
  end

  def self.available_re_files
    Dir.glob(File.join(project_dir, '*.re')).map { |f| File.basename(f) }.sort
  end

  def self.verify_project_structure
    setup_test_environment
    
    structure = {
      config_exists: File.exist?(config_file),
      catalog_exists: File.exist?(catalog_file),
      re_files: available_re_files,
      images_dir: Dir.exist?(File.join(project_dir, 'images')),
      sty_dir: Dir.exist?(File.join(project_dir, 'sty'))
    }

    puts "=== Test Project Structure ==="
    puts "Config file: #{structure[:config_exists] ? '✅' : '❌'}"
    puts "Catalog file: #{structure[:catalog_exists] ? '✅' : '❌'}"
    puts "Images directory: #{structure[:images_dir] ? '✅' : '❌'}"
    puts "Style directory: #{structure[:sty_dir] ? '✅' : '❌'}"
    puts "Re:VIEW files: #{structure[:re_files].size}"
    structure[:re_files].each { |f| puts "  - #{f}" }
    puts "============================"

    structure
  end
end