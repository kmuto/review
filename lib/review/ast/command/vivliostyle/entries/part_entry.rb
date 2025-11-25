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
          # PartEntry generates the part divider HTML
          class PartEntry < Entry
            attr_reader :part

            def initialize(context:, part:)
              super(context: context)
              @part = part
              @filename = "part_#{part.number}.html"
              @title = "#{I18n.t('part', part.number)} #{part.name}"
            end

            def render
              <<~HTML
                <div class="part">
                  <h1 class="part-number">#{h(I18n.t('part', part.number))}</h1>
                  <h2 class="part-title">#{h(part.name)}</h2>
                </div>
              HTML
            end
          end
        end
      end
    end
  end
end
