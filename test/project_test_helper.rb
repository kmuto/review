# frozen_string_literal: true

require 'English'
require_relative 'test_helper'
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

      # Create temporary config for specific AST mode
      config_content = File.read('config.yml')

      # Update AST configuration based on parameters
      temp_config = if config_content.include?('ast:')
                      config_content.gsub(/^ast:.*?(?=^\S|\z)/m) do |_ast_section|
                        <<~AST_CONFIG
            ast:
              mode: #{ast_mode}
              stage: #{ast_stage}
              debug: #{debug}
              performance: #{debug}
          AST_CONFIG
                      end
                    else
                      # Add AST configuration if not present
                      config_content + <<~AST_CONFIG

          ast:
            mode: #{ast_mode}
            stage: #{ast_stage}
            debug: #{debug}
            performance: #{debug}
        AST_CONFIG
                    end

      # Write temporary config
      temp_config_file = "temp_config_#{target_format}.yml"
      File.write(temp_config_file, temp_config)

      # Run compilation with absolute paths
      review_root = File.expand_path('..', File.dirname(__FILE__))
      cmd = "bundle exec #{File.join(review_root, 'bin', 'review-compile')} --yaml=#{temp_config_file} --target=#{target_format}"

      puts "DEBUG: Running command: #{cmd}" if debug
      result = case target_format
               when 'html', 'latex', 'json'
                 `#{cmd} basic_elements.re 2>&1`
               else
                 `#{cmd} comprehensive_test.re 2>&1`
               end
      unless $CHILD_STATUS.success?
        puts "DEBUG: Command failed with exit code: #{$CHILD_STATUS.exitstatus}"
        puts "DEBUG: Command output: #{result}"
        puts "DEBUG: Working directory: #{Dir.pwd}"
        puts "DEBUG: Config file exists: #{File.exist?(temp_config_file)}"
        puts "DEBUG: Basic elements file exists: #{File.exist?('basic_elements.re')}"
      end

      {
        success: $CHILD_STATUS.success?,
        output: result,
        exit_code: $CHILD_STATUS.exitstatus
      }
    ensure
      Dir.chdir(old_dir)
      # Clean up temporary config file
      temp_config_file = File.join(project_dir, "temp_config_#{target_format}.yml")
      FileUtils.rm_f(temp_config_file)
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

    puts '=== Test Project Structure ==='
    puts "Config file: #{structure[:config_exists] ? '✅' : '❌'}"
    puts "Catalog file: #{structure[:catalog_exists] ? '✅' : '❌'}"
    puts "Images directory: #{structure[:images_dir] ? '✅' : '❌'}"
    puts "Style directory: #{structure[:sty_dir] ? '✅' : '❌'}"
    puts "Re:VIEW files: #{structure[:re_files].size}"
    structure[:re_files].each { |f| puts "  - #{f}" }
    puts '============================'

    structure
  end
end
