# Copyright (c) 2008-2020 Minero Aoki, Kenshi Muto, Masayoshi Takahashi,
#                         KADO Masanori
#               2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#
require 'nkf'
require 'digest'

module ReVIEW
  module TextUtils
    def detab(str, ts = 8)
      add = 0
      len = nil
      str.gsub("\t") do
        len = ts - ($`.size + add) % ts
        add += len - 1
        ' ' * len
      end
    end

    def split_paragraph(lines)
      pre = pre_paragraph
      post = post_paragraph
      trimmed_lines = trim_lines(lines)

      blocked_lines = [[]]
      trimmed_lines.each do |element|
        if element.empty?
          blocked_lines << [] if blocked_lines.last != []
        else
          blocked_lines.last << element
        end
      end

      blocked_lines.map! { |i| join_lines_to_paragraph(i) }

      if pre && post
        blocked_lines.map! { |i| pre + i + post }
      end

      blocked_lines
    end

    def add_space?(line1, line2, lang, lazy = nil)
      # https://drafts.csswg.org/css-text-3/#line-break-transform
      tail = line1[-1]
      head = line2[0]
      if tail.nil? || head.nil?
        return nil
      end

      space = true
      # rule 2
      if %i[F W H].include?(Unicode::Eaw.property(tail)) &&
         %i[F W H].include?(Unicode::Eaw.property(head)) &&
         tail !~ /\p{Hangul}/ && head !~ /\p{Hangul}/
        space = nil
      end

      if %w[ja zh zh_CN zh_TW yi].include?(lang)
        # rule 3
        if (%i[F W H].include?(Unicode::Eaw.property(tail)) &&
            tail !~ /\p{Hangul}/ &&
            (head =~ /\p{P}/ || head =~ /\p{S}/ || Unicode::Eaw.property(head) == :A)) ||
           (%i[F W H].include?(Unicode::Eaw.property(head)) &&
            head !~ /\p{Hangul}/ &&
            (tail =~ /\p{P}/ || head =~ /\p{S}/ || Unicode::Eaw.property(tail) == :A))
          space = nil
        end

        # lazy than rule 3, but it looks better
        if lazy &&
           (%i[F W H].include?(Unicode::Eaw.property(tail)) &&
            tail !~ /\p{Hangul}/) ||
           (%i[F W H].include?(Unicode::Eaw.property(head)) &&
            head !~ /\p{Hangul}/)
          space = nil
        end
      end
      space
    end

    def join_lines_to_paragraph(lines)
      unless @book.config['join_lines_by_lang']
        return lines.join
      end

      lazy = true
      lang = 'ja'
      0.upto(lines.size - 2) do |n|
        if add_space?(lines[n], lines[n + 1], lang, lazy)
          lines[n] += ' '
        end
      end
      lines.join
    end

    def defer_math_image(str, path, key)
      # for Re:VIEW >3
      File.open(File.join(File.dirname(path), "__IMGMATH_BODY__#{key}.tex"), 'w') do |f|
        f.puts str
      end
      File.open(File.join(File.dirname(path), '__IMGMATH_BODY__.map'), 'a+') do |f|
        f.puts key
      end
    end

    private

    # remove elements at the back of `lines` if element is empty string
    # (`lines` should be Array of String.)
    #
    def trim_lines(lines)
      new_lines = lines.dup
      while new_lines[-1] && new_lines[-1].strip.empty?
        new_lines.pop
      end
      new_lines
    end
  end
end
