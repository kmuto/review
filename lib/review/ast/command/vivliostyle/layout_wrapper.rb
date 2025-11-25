# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'erb'
require 'review/template'
require 'review/loggable'

module ReVIEW
  module AST
    module Command
      module Vivliostyle
        # LayoutWrapper wraps HTML content with layout template
        class LayoutWrapper
          include ERB::Util
          include Loggable

          def initialize(context:)
            @context = context
            @logger = ReVIEW.logger
          end

          def wrap(body, title:)
            @body = body
            @title = title
            @language = @context.config['language']
            @stylesheets = @context.stylesheets
            @javascripts = @context.javascripts
            @config = @context.config

            template_path = @context.template_path('vivliostyle/layout.html.erb')
            ReVIEW::Template.generate(path: template_path, binding: binding)
          end

          def write_html(filename, content)
            File.write(@context.output_path(filename), content)
          end
        end
      end
    end
  end
end
