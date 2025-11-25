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
          # ColophonEntry generates the colophon (imprint) HTML
          class ColophonEntry < Entry
            def initialize(context:)
              super
              @filename = 'colophon.html'
              @title = I18n.t('colophontitle')
            end

            def render
              template_path = @context.template_path('vivliostyle/_colophon.html.erb')
              if template_path && File.exist?(template_path)
                ReVIEW::Template.generate(path: template_path, binding: binding)
              else
                fallback_colophon
              end
            end

            private

            def fallback_colophon
              items = []
              (config['colophon_order'] || []).each do |key|
                value = config.name_of(key)
                next unless value

                label = I18n.t("colophon_#{key}", nil) || key
                items << "<dt>#{h(label)}</dt><dd>#{h(value)}</dd>"
              end

              <<~HTML
                <div class="colophon">
                  <h1>#{h(config.name_of('booktitle'))}</h1>
                  <dl>
                    #{items.join("\n")}
                  </dl>
                  <p class="date">#{h(config['date'].to_s)}</p>
                </div>
              HTML
            end
          end
        end
      end
    end
  end
end
