# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'tmpdir'
require 'fileutils'
require 'review/template'
require_relative 'layout_wrapper'

module ReVIEW
  module AST
    module Command
      module Vivliostyle
        # BuildContext manages build configuration, paths, and shared state
        class BuildContext
          attr_reader :config, :basedir, :build_path, :buildonly, :layout_wrapper
          attr_accessor :book
          attr_reader :entry_files, :stylesheets, :javascripts

          def initialize(config:, basedir:, debug: false, buildonly: nil)
            @config = config
            @basedir = basedir
            @debug = debug
            @buildonly = buildonly
            @build_path = nil
            @book = nil
            @entry_files = []
            @stylesheets = []
            @javascripts = []
            @layout_wrapper = LayoutWrapper.new(context: self)
          end

          def debug?
            @debug
          end

          def setup_build_directory
            @build_path = if @debug
                            path = File.expand_path("#{@config['bookname']}-vivliostyle", Dir.pwd)
                            FileUtils.rm_rf(path, secure: true)
                            Dir.mkdir(path)
                            path
                          else
                            Dir.mktmpdir("#{@config['bookname']}-vivliostyle-")
                          end
          end

          def cleanup
            return if @debug || @build_path.nil?

            FileUtils.remove_entry_secure(@build_path)
          end

          def add_entry_file(filename)
            @entry_files << filename
          end

          def add_stylesheet(filename)
            @stylesheets << filename
          end

          def add_javascript(script)
            @javascripts << script
          end

          # Returns absolute path from basedir
          def source_path(relative)
            File.join(@basedir, relative)
          end

          # Returns absolute path from build_path
          def output_path(relative)
            File.join(@build_path, relative)
          end

          # Find template file path (user layouts dir first, then system templates)
          def template_path(relative)
            # Check user's layouts directory first
            user_path = File.join(@basedir, 'layouts', relative)
            return user_path if File.exist?(user_path)

            # Check system templates
            system_path = File.join(ReVIEW::Template::TEMPLATE_DIR, relative)
            return system_path if File.exist?(system_path)

            nil
          end
        end
      end
    end
  end
end
