# encoding: utf-8
#
# $Id: latexutils.rb 2204 2006-03-18 06:10:26Z aamine $
#
# Copyright (c) 2002-2006 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

module ReVIEW

  module LaTeXUtils

    METACHARS = {
      '#'  => '\#',
      "$"  => '\textdollar{}',
      '%' => '\%',
      '&' => '\&',
      '{' => '\{',
      '}' => '\}',
      '_'  => '\textunderscore{}',
      '^' => '\textasciicircum{}',
      '~' => '\textasciitilde{}',
      '|' => '\textbar{}',
      '<'  => '\textless{}',
      '>'  => '\textgreater{}',
      "\\" => '\reviewbackslash{}',
      "-" => '{-}',

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

      'ｱ' => '\aj半角{ア}',
      'ｲ' => '\aj半角{イ}',
      'ｳ' => '\aj半角{ウ}',
      'ｴ' => '\aj半角{エ}',
      'ｵ' => '\aj半角{オ}',
      'ｶ' => '\aj半角{カ}',
      'ｷ' => '\aj半角{キ}',
      'ｸ' => '\aj半角{ク}',
      'ｹ' => '\aj半角{ケ}',
      'ｺ' => '\aj半角{コ}',
      'ｻ' => '\aj半角{サ}',
      'ｼ' => '\aj半角{シ}',
      'ｽ' => '\aj半角{ス}',
      'ｾ' => '\aj半角{セ}',
      'ｿ' => '\aj半角{ソ}',
      'ﾀ' => '\aj半角{タ}',
      'ﾁ' => '\aj半角{チ}',
      'ﾂ' => '\aj半角{ツ}',
      'ﾃ' => '\aj半角{テ}',
      'ﾄ' => '\aj半角{ト}',
      'ﾅ' => '\aj半角{ナ}',
      'ﾆ' => '\aj半角{ニ}',
      'ﾇ' => '\aj半角{ヌ}',
      'ﾈ' => '\aj半角{ネ}',
      'ﾉ' => '\aj半角{ノ}',
      'ﾊ' => '\aj半角{ハ}',
      'ﾋ' => '\aj半角{ヒ}',
      'ﾌ' => '\aj半角{フ}',
      'ﾍ' => '\aj半角{ヘ}',
      'ﾎ' => '\aj半角{ホ}',
      'ﾏ' => '\aj半角{マ}',
      'ﾐ' => '\aj半角{ミ}',
      'ﾑ' => '\aj半角{ム}',
      'ﾒ' => '\aj半角{メ}',
      'ﾓ' => '\aj半角{モ}',
      'ﾔ' => '\aj半角{ヤ}',
      'ﾕ' => '\aj半角{ユ}',
      'ﾖ' => '\aj半角{ヨ}',
      'ﾗ' => '\aj半角{ラ}',
      'ﾘ' => '\aj半角{リ}',
      'ﾙ' => '\aj半角{ル}',
      'ﾚ' => '\aj半角{レ}',
      'ﾛ' => '\aj半角{ロ}',
      'ﾜ' => '\aj半角{ワ}',
      'ｦ' => '\aj半角{ヲ}',
      'ﾝ' => '\aj半角{ン}',
      'ｧ' => '\aj半角{ァ}',
      'ｨ' => '\aj半角{ィ}',
      'ｩ' => '\aj半角{ゥ}',
      'ｪ' => '\aj半角{ェ}',
      'ｫ' => '\aj半角{ォ}',
      'ｯ' => '\aj半角{ッ}',
      'ｬ' => '\aj半角{ャ}',
      'ｭ' => '\aj半角{ュ}',
      'ｮ' => '\aj半角{ョ}',
      'ﾞ' => '\aj半角{゛}',
      'ﾟ' => '\aj半角{゜}',
      'ｰ' => '\aj半角{ー}',

      '･' => '\aj半角{・}',

    }

    METACHARS_RE = /[#{Regexp.escape(METACHARS.keys.join(''))}]/

    METACHARS_INVERT = METACHARS.invert

    def escape_latex(str)
      str.gsub(METACHARS_RE) {|s|
        METACHARS[s] or raise "unknown trans char: #{s}"
      }
    end

    alias escape escape_latex

    def unescape_latex(str)
      metachars_invert_re = Regexp.new(METACHARS_INVERT.keys.collect{|key|  Regexp.escape(key)}.join('|'))
      str.gsub(metachars_invert_re) {|s|
        METACHARS_INVERT[s] or raise "unknown trans char: #{s}"
      }
    end

    def escape_index(str)
      str.gsub(/[@!|"]/) {|s| '"' + s }
    end

    def escape_url(str)
      str.gsub(/[\#%]/) {|s| '\\'+s }
    end

    def macro(name, *args)
      "\\#{name}" + args.map {|a| "{#{a}}" }.join('')
    end

  end

end
