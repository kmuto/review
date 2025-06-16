# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  module AST
    # Config - Configuration management for AST mode and hybrid migration
    #
    # This class handles:
    # - Configuration file parsing for AST settings
    # - Environment variable overrides
    # - Stage-based element configuration
    # - Performance measurement settings
    class Config
      # Cache for frequently accessed configurations
      @config_cache = {}
      @cache_mutex = Mutex.new

      def initialize(config = nil)
        @config = config || ReVIEW::Configure.values
        @ast_config = @config['ast'] || {}

        # Create cache key for this configuration
        @cache_key = create_cache_key

        # Try to get cached compiler options
        cached = self.class.get_cached_options(@cache_key)
        if cached
          @cached_compiler_options = cached
        end
      end

      class << self
        def get_cached_options(cache_key)
          @cache_mutex.synchronize { @config_cache[cache_key] }
        end

        def set_cached_options(cache_key, options)
          @cache_mutex.synchronize { @config_cache[cache_key] = options }
        end

        def clear_cache
          @cache_mutex.synchronize { @config_cache.clear }
        end
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
          debug: debug_enabled?
        }
      end

      # Create compiler options based on configuration
      def compiler_options
        # Return cached options if available
        return @cached_compiler_options if @cached_compiler_options

        mode = ast_mode
        options = case mode
                  when :off
                    { ast_mode: false }
                  when :full
                    { ast_mode: true }
                  when :auto
                    # Auto mode: default to traditional mode
                    { ast_mode: false }
                  else
                    { ast_mode: false }
                  end

        # Cache the options
        self.class.set_cached_options(@cache_key, options)
        @cached_compiler_options = options

        options
      end

      private

      # Create a cache key based on current configuration
      def create_cache_key
        # Include relevant configuration that affects compiler options
        # Use raw config values to avoid circular dependencies
        key_data = {
          config_mode: @ast_config['mode'],
          env_mode: ENV['REVIEW_AST_MODE']
        }
        key_data.hash
      end

      def parse_ast_mode(mode_str)
        case mode_str.to_s.downcase
        when 'full', 'true', '1'
          :full
        when 'off', 'false', '0'
          :off
        when 'auto'
          :auto
        else
          :auto
        end
      end
    end
  end
end
