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

    MATACHARS = {
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
      "\\" => '\reviewbackslash{}'
    }

    METACHARS_RE = /[#{Regexp.escape(MATACHARS.keys.join(''))}]/

    MATACHARS_INVERT = MATACHARS.invert

    def escape_latex(str)
      str.gsub(METACHARS_RE) {|s|
        MATACHARS[s] or raise "unknown trans char: #{s}"
      }
    end

    alias escape escape_latex

    def unescape_latex(str)
      metachars_invert_re = Regexp.new(MATACHARS_INVERT.keys.collect{|key|  Regexp.escape(key)}.join('|'))
      str.gsub(metachars_invert_re) {|s|
        MATACHARS_INVERT[s] or raise "unknown trans char: #{s}"
      }
    end

    def escape_index(str)
      str.gsub(/[@!|"]/) {|s| '"' + s }
    end

    def macro(name, *args)
      "\\#{name}" + args.map {|a| "{#{a}}" }.join('')
    end

  end

end
