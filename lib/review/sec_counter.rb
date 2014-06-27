# encoding: utf-8
#
# Copyright (c) 2008-2014 Minero Aoki, Kenshi Muto, Masayoshi Takahashi,
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
      if n >= 0
        @counter[n] += 1
      end
      if @counter.size > n
        (n+1 .. @counter.size).each do |i|
          @counter[i] = 0
        end
      end
    end

    def anchor(level)
      str = "#{@chapter.number}"
      0.upto(level-2) do |i|
        str << "-#{@counter[i]}"
      end
      str
    end

    def prefix(level, secnolevel)
      return nil if @chapter.number.blank?

      if level == 1
        if secnolevel >= 1
          num = @chapter.number
          placeholder = if @chapter.is_a? ReVIEW::Book::Part
                          'part'
                        elsif @chapter.on_POSTDEF?
                          'appendix'
                        else
                          'chapter'
                        end

          num = ReVIEW.book.format_appendix(num) if placeholder == "appendix"
          return "#{I18n.t(placeholder, num)}#{I18n.t("chapter_postfix")}"
        end
      else
        if secnolevel >= level
          prefix = @chapter.number.to_s
          prefix = ReVIEW.book.format_appendix(@chapter.number).to_s if @chapter.on_POSTDEF?
          0.upto(level-2) do |i|
            prefix << ".#{@counter[i]}"
          end
          prefix << I18n.t("chapter_postfix")
          return prefix
        end
      end
    end
  end
end
