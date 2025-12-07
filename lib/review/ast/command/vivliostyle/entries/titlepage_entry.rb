# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/i18n'
require 'review/template'
require_relative '../entry'

module ReVIEW
  module AST
    module Command
      module Vivliostyle
        module Entries
          # TitlepageEntry generates the title page HTML
          class TitlepageEntry < Entry
            def initialize(context:)
              super
              @filename = 'titlepage.html'
              @title = config.name_of('booktitle')
            end

            def render
              template_path = @context.template_path('vivliostyle/_titlepage.html.erb')
              if template_path && File.exist?(template_path)
                ReVIEW::Template.generate(path: template_path, binding: binding)
              else
                fallback_titlepage
              end
            end

            private

            def fallback_titlepage
              author_names = join_with_separator(config.names_of('aut'), I18n.t('names_splitter'))
              <<~HTML
                <div class="titlepage">
                  <h1 class="booktitle">#{h(config.name_of('booktitle'))}</h1>
                  <p class="author">#{h(author_names)}</p>
                </div>
              HTML
            end
          end
        end
      end
    end
  end
end
