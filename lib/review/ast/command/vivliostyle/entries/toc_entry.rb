# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/i18n'
require_relative '../entry'

module ReVIEW
  module AST
    module Command
      module Vivliostyle
        module Entries
          # TocEntry generates the table of contents HTML
          class TocEntry < Entry
            def initialize(context:)
              super
              @filename = 'toc.html'
              @title = I18n.t('toctitle')
            end

            def render
              toc_items = []

              book.parts.each do |part|
                if part.name.present? && !part.file?
                  toc_items << %Q(<li class="part">#{h(part.name)}</li>)
                end
                part.chapters.each do |chap|
                  toc_items << %Q(<li><a href="#{chap.name}.html">#{h(chap.title)}</a></li>)
                end
              end

              <<~HTML
                <nav class="toc">
                  <h1>#{h(I18n.t('toctitle'))}</h1>
                  <ol>
                    #{toc_items.join("\n")}
                  </ol>
                </nav>
              HTML
            end
          end
        end
      end
    end
  end
end
