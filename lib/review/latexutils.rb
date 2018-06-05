# Copyright (c) 2002-2006 Minero Aoki
# Copyright (c) 2006-2017 Minero Aoki, Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'nkf'

module ReVIEW
  module LaTeXUtils
    def initialize_metachars(texcommand)
      @metachars = {
        '#' => '\#',
        '$' => '\textdollar{}',
        '%' => '\%',
        '&' => '\&',
        '{' => '\{',
        '}' => '\}',
        '_' => '\textunderscore{}',
        '^' => '\textasciicircum{}',
        '~' => '\textasciitilde{}',
        '|' => '\textbar{}',
        '<' => '\textless{}',
        '>' => '\textgreater{}',
        '\\' => '\reviewbackslash{}',
        '-' => '{-}'
      }

      if File.basename(texcommand, '.*') == 'platex'
        @metachars.merge!(
          '⓪' => '\UTF{24EA}',
          '①' => '\UTF{2460}',
          '②' => '\UTF{2461}',
          '③' => '\UTF{2462}',
          '④' => '\UTF{2463}',
          '⑤' => '\UTF{2464}',
          '⑥' => '\UTF{2465}',
          '⑦' => '\UTF{2466}',
          '⑧' => '\UTF{2467}',
          '⑨' => '\UTF{2468}',
          '⑩' => '\UTF{2469}',
          '⑪' => '\UTF{246A}',
          '⑫' => '\UTF{246B}',
          '⑬' => '\UTF{246C}',
          '⑭' => '\UTF{246D}',
          '⑮' => '\UTF{246E}',
          '⑯' => '\UTF{246F}'
        )

        kanalist = %w[｡ ｢ ｣ ､ ･ ｦ ｧ ｨ ｩ ｪ ｫ ｬ ｭ ｮ ｯ ｰ ｱ ｲ ｳ ｴ
                      ｵ ｶ ｷ ｸ ｹ ｺ ｻ ｼ ｽ ｾ ｿ ﾀ ﾁ ﾂ ﾃ ﾄ ﾅ ﾆ ﾇ ﾈ ﾉ ﾊ ﾋ ﾌ ﾍ ﾎ ﾏ
                      ﾐ ﾑ ﾒ ﾓ ﾔ ﾕ ﾖ ﾗ ﾘ ﾙ ﾚ ﾛ ﾜ ﾝ ﾞ ﾟ]
        kanalist.each do |char|
          char_jisx0208 = NKF.nkf('-WwX', char)
          @metachars[char] = "\\aj半角{#{char_jisx0208}}"
        end
      end

      @metachars_re = /[#{Regexp.escape(@metachars.keys.join(''))}]/u

      @metachars_invert = @metachars.invert
    end

    def escape_latex(str)
      str.gsub(@metachars_re) { |s| @metachars[s] or raise "unknown trans char: #{s}" }
    end

    alias_method :escape, :escape_latex

    def unescape_latex(str)
      metachars_invert_re = Regexp.new(@metachars_invert.keys.collect { |key| Regexp.escape(key) }.join('|'))
      str.gsub(metachars_invert_re) { |s| @metachars_invert[s] or raise "unknown trans char: #{s}" }
    end

    alias_method :unescape, :unescape_latex

    def escape_index(str)
      str.gsub(/[@!|"]/) { |s| '"' + s }
    end

    def escape_url(str)
      str.gsub(/[\#%]/) { |s| '\\' + s }
    end

    def macro(name, *args)
      "\\#{name}" + args.map { |a| "{#{a}}" }.join
    end
  end
end
