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
