# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'erb'
require 'review/loggable'

module ReVIEW
  module AST
    module Command
      module Vivliostyle
        # Entry is the base class for all HTML output entries
        # Each Entry represents one HTML file to be generated
        class Entry
          include ERB::Util
          include Loggable

          attr_reader :filename, :title

          def initialize(context:)
            @context = context
            @filename = nil
            @title = nil
            @logger = ReVIEW.logger
          end

          # Render HTML body content (to be implemented by subclasses)
          def render
            raise NotImplementedError, "#{self.class}#render must be implemented"
          end

          # Write the entry to file
          def write
            body = render
            html = layout_wrapper.wrap(body, title: @title)
            layout_wrapper.write_html(@filename, html)
            @context.add_entry_file(@filename)
          end

          # Generate the entry (render + layout + write)
          def generate
            write
          end

          protected

          def config
            @context.config
          end

          def book
            @context.book
          end

          def layout_wrapper
            @context.layout_wrapper
          end

          # Helper to join array values with separator
          def join_with_separator(value, sep)
            if value.is_a?(Array)
              value.join(sep)
            else
              value.to_s
            end
          end
        end
      end
    end
  end
end
