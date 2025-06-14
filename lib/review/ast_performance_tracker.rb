# frozen_string_literal: true

# Copyright (c) 2024 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  # ASTPerformanceTracker - Performance measurement and logging for AST compilation
  #
  # This class handles:
  # - Performance measurement tracking
  # - Compilation time statistics
  # - Debug logging for performance metrics
  # - Statistics aggregation and reporting
  class ASTPerformanceTracker
    def initialize(enabled: false)
      @enabled = enabled || ENV['REVIEW_AST_PERFORMANCE'] == 'true'
      @stats = {}
      @start_times = {}
    end

    attr_reader :stats

    # Check if performance tracking is enabled
    def enabled?
      @enabled
    end

    # Start tracking a performance metric
    def start_timing(metric)
      return unless @enabled

      @start_times[metric] = Time.now
    end

    # End tracking and record the metric
    def end_timing(metric)
      return unless @enabled

      start_time = @start_times.delete(metric)
      return unless start_time

      duration = Time.now - start_time
      @stats[metric] = duration
    end

    # Record a custom metric value
    def record_metric(metric, value)
      return unless @enabled

      @stats[metric] = value
    end

    # Get a specific metric value
    def get_metric(metric)
      @stats[metric]
    end

    # Get all performance statistics
    def all_stats
      @stats.dup
    end

    # Log performance statistics to debug output
    def log_statistics
      return unless @enabled && @stats.any?

      warn 'DEBUG: === Performance Statistics ==='
      @stats.each do |metric, value|
        if metric.to_s.include?('time')
          warn "DEBUG:   #{metric}: #{(value * 1000).round(2)}ms"
        else
          warn "DEBUG:   #{metric}: #{value}"
        end
      end
      warn 'DEBUG: ================================'
    end

    # Clear all statistics
    def clear
      @stats.clear
      @start_times.clear
    end

    # Measure execution time of a block
    def measure(metric)
      return yield unless @enabled

      start_timing(metric)
      result = yield
      end_timing(metric)
      result
    end

    # Get formatted timing for a specific metric
    def formatted_time(metric)
      time = @stats[metric]
      return 'N/A' unless time

      "#{(time * 1000).round(2)}ms"
    end

    # Check if any metrics have been recorded
    def has_metrics?
      @stats.any?
    end
  end
end
