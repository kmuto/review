# Copyright (c) 2008-2017 Minero Aoki, Kenshi Muto, Masayoshi Takahashi,
#                         KADO Masanori
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

module ReVIEW
  # Secion Counter class
  #
  class SecCounter
    def initialize(n, chapter)
      @chapter = chapter
      reset(n)
    end

    def reset(n)
      @counter = Array.new(n, 0)
    end

    def inc(level)
      n = level - 2
      @counter[n] += 1 if n >= 0
      (n + 1..@counter.size).each { |i| @counter[i] = 0 } if @counter.size > n
    end

    def anchor(level)
      str = @chapter.format_number(false)
      0.upto(level - 2) { |i| str << "-#{@counter[i]}" }
      str
    end

    def prefix(level, secnolevel)
      return nil if @chapter.number.blank?

      if level == 1
        return nil unless secnolevel >= 1
        if @chapter.is_a?(ReVIEW::Book::Part)
          num = @chapter.number
          "#{I18n.t('part', num)}#{I18n.t('chapter_postfix')}"
        else
          "#{@chapter.format_number}#{I18n.t('chapter_postfix')}"
        end
      elsif secnolevel >= level
        prefix = if @chapter.is_a?(ReVIEW::Book::Part)
                   I18n.t('part_short', @chapter.number)
                 else
                   @chapter.format_number(false)
                 end
        0.upto(level - 2) { |i| prefix << ".#{@counter[i]}" }
        prefix << I18n.t('chapter_postfix')
        prefix
      end
    end
  end
end
