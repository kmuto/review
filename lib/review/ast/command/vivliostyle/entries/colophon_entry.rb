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
              ReVIEW::Template.generate(path: template_path, binding: binding)
            end

            private

            # ISBN with hyphens
            def isbn_hyphen
              str = config['isbn'].to_s
              return nil if str.empty?

              if /\A\d{10}\Z/.match?(str)
                "#{str[0..0]}-#{str[1..5]}-#{str[6..8]}-#{str[9..9]}"
              elsif /\A\d{13}\Z/.match?(str)
                "#{str[0..2]}-#{str[3..3]}-#{str[4..8]}-#{str[9..11]}-#{str[12..12]}"
              else
                str
              end
            end

            # Generate colophon history section
            def colophon_history
              @col_history = build_col_history
              template_path = @context.template_path('vivliostyle/_colophon_history.html.erb')
              ReVIEW::Template.generate(path: template_path, binding: binding)
            end

            # Accessor for template
            def col_history
              @col_history ||= build_col_history
            end

            def build_col_history
              history = []
              if config['history']
                config['history'].each_with_index do |items, edit|
                  items.each_with_index do |item, rev|
                    editstr = edit == 0 ? I18n.t('first_edition') : I18n.t('nth_edition', (edit + 1).to_s)
                    revstr = I18n.t('nth_impression', (rev + 1).to_s)
                    if /\A\d+-\d+-\d+\Z/.match?(item)
                      history << I18n.t('published_by1', [date_to_s(item), editstr + revstr])
                    elsif /\A(\d+-\d+-\d+)[\s　](.+)/.match?(item)
                      # custom date with string
                      item.match(/\A(\d+-\d+-\d+)[\s　](.+)/) do |m|
                        history << I18n.t('published_by3', [date_to_s(m[1]), m[2]])
                      end
                    else
                      # free format
                      history << item
                    end
                  end
                end
              end
              history
            end

            def date_to_s(date)
              require 'date'
              d = Date.parse(date)
              d.strftime(I18n.t('date_format'))
            end

            # Join array with separator
            def join_with_separator(ary, sep)
              return '' if ary.nil? || ary.empty?

              ary.join(sep)
            end

          end
        end
      end
    end
  end
end
