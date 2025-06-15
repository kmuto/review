# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  # ASTConfig - Configuration management for AST mode and hybrid migration
  #
  # This class handles:
  # - Configuration file parsing for AST settings
  # - Environment variable overrides
  # - Stage-based element configuration
  # - Performance measurement settings
  class ASTConfig
    # Predefined migration stages with their corresponding elements
    MIGRATION_STAGES = {
      1 => [:headline],
      2 => %i[headline paragraph],
      3 => %i[headline paragraph ulist olist dlist],
      4 => %i[headline paragraph ulist olist dlist table emtable imgtable],
      5 => %i[headline paragraph ulist olist dlist table emtable imgtable image indepimage numberlessimage],
      6 => %i[headline paragraph ulist olist dlist table emtable imgtable image indepimage numberlessimage list listnum emlist emlistnum cmd source],
      7 => %i[headline paragraph ulist olist dlist table emtable imgtable image list emlist cmd source inline]
    }.freeze

    def initialize(config = nil)
      @config = config || ReVIEW::Configure.values
      @ast_config = @config['ast'] || {}
    end

    # Get AST mode based on configuration and environment
    def ast_mode
      # Environment variable override
      env_mode = ENV['REVIEW_AST_MODE']
      return parse_ast_mode(env_mode) if env_mode

      # Configuration file setting
      mode = @ast_config['mode'] || 'auto'
      parse_ast_mode(mode)
    end

    # Get AST elements for hybrid mode
    def ast_elements
      # Environment variable override
      env_elements = ENV['REVIEW_AST_ELEMENTS']
      return parse_elements(env_elements) if env_elements

      # Stage-based configuration
      stage = ast_stage
      return MIGRATION_STAGES[stage] || [] if stage

      # Explicit elements configuration
      elements = @ast_config['elements'] || []
      elements.map(&:to_sym)
    end

    # Get migration stage
    def ast_stage
      # Environment variable override
      env_stage = ENV['REVIEW_AST_STAGE']
      return env_stage.to_i if env_stage&.match?(/^\d+$/)

      # Configuration file setting
      stage = @ast_config['stage']
      stage.to_i if stage.is_a?(Integer) && stage > 0
    end

    # Check if debug mode is enabled
    def debug_enabled?
      # Environment variable override (already handled in ASTCompiler)
      return true if ENV['REVIEW_DEBUG_AST'] == 'true'

      # Configuration file setting
      @ast_config['debug'] == true
    end

    # Check if performance measurement is enabled
    def performance_enabled?
      # Environment variable override
      return true if ENV['REVIEW_AST_PERFORMANCE'] == 'true'

      # Configuration file setting
      @ast_config['performance'] == true
    end

    # Get complete AST configuration
    def to_h
      {
        mode: ast_mode,
        elements: ast_elements,
        stage: ast_stage,
        debug: debug_enabled?,
        performance: performance_enabled?
      }
    end

    # Create compiler options based on configuration
    def compiler_options
      mode = ast_mode
      case mode
      when :off
        { ast_mode: false }
      when :full
        { ast_mode: true, ast_elements: [] }
      when :hybrid
        { ast_mode: true, ast_elements: ast_elements }
      when :auto
        # Auto mode: enable AST if stage/elements are specified, otherwise off
        if ast_stage || ast_elements.any?
          { ast_mode: true, ast_elements: ast_elements }
        else
          { ast_mode: false } # Default, can be overridden by specific builders
        end
      else # rubocop:disable Lint/DuplicateBranch
        { ast_mode: false }
      end
    end

    # Get stage description for logging
    def stage_description
      stage = ast_stage
      return 'No stage specified' unless stage

      elements = MIGRATION_STAGES[stage]
      return 'Invalid stage' unless elements

      "Stage #{stage}: #{elements.join(', ')}"
    end

    private

    def parse_ast_mode(mode_str)
      case mode_str.to_s.downcase
      when 'full', 'true', '1'
        :full
      when 'hybrid'
        :hybrid
      when 'off', 'false', '0'
        :off
      when 'auto'
        :auto
      else # rubocop:disable Lint/DuplicateBranch
        :auto
      end
    end

    def parse_elements(elements_str)
      elements_str.split(',').map { |e| e.strip.to_sym }.reject(&:empty?)
    end
  end
end
