# encoding: utf-8
#
# Copyright (c) 2002-2006 Minero Aoki
# Copyright (c) 2006-2016 Minero Aoki, Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'nkf'

module ReVIEW

  module LaTeXUtils

    METACHARS = {
      '#' => '\#',
      "$" => '\textdollar{}',
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
      "\\" => '\reviewbackslash{}',
      "-" => '{-}'
    }

    METACHARS_RE = /[#{Regexp.escape(METACHARS.keys.join(''))}]/u

    METACHARS_INVERT = METACHARS.invert

    def escape_latex(str)
      str.gsub(METACHARS_RE) {|s|
        METACHARS[s] or raise "unknown trans char: #{s}"
      }
    end

    alias_method :escape, :escape_latex

    def unescape_latex(str)
      metachars_invert_re = Regexp.new(METACHARS_INVERT.keys.collect{|key| Regexp.escape(key)}.join('|'))
      str.gsub(metachars_invert_re) {|s|
        METACHARS_INVERT[s] or raise "unknown trans char: #{s}"
      }
    end

    alias_method :unescape, :unescape_latex

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
