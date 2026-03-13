# frozen_string_literal: true

# Copyright (c) 2025 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

module ReVIEW
  # Immutable snapshot of a source file location (filename and line number)
  class SnapshotLocation
    def initialize(filename, lineno)
      @filename = filename
      @lineno = lineno
      freeze
    end

    attr_reader :filename, :lineno

    def string
      "#{@filename}:#{@lineno}"
    end

    def to_h
      {
        filename: filename,
        lineno: lineno
      }
    end

    # Format location information for error messages
    # Returns a string like " at line 42 in chapter01.re"
    def format_for_error
      info = " at line #{@lineno}"
      info += " in #{@filename}" if @filename
      info
    end

    alias_method :to_s, :string

    def snapshot
      self
    end
  end
end
