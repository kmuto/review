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
      '#'  => '\symbol{"23}',
      "$"  => '\symbol{"24}',
      '%' => '\%',
      '&' => '\&',
      '{' => '\{',
      '}' => '\}',
      '_'  => '\symbol{"5F}',
      '^' => '\textasciicircum{}',
      '~' => '\textasciitilde{}',
      '|' => '\textbar{}',
      '<'  => '\symbol{"3C}',
      '>'  => '\symbol{"3E}',
      "\\" => '\symbol{"5C}'
    }

    METACHARS_RE = /[#{Regexp.escape(MATACHARS.keys.join(''))}]/

    def escape_latex(str)
      str.gsub(METACHARS_RE) {|s|
        MATACHARS[s] or raise "unknown trans char: #{s}"
      }
    end

    alias escape escape_latex

    def escape_index(str)
      str.gsub(/[@!|"]/) {|s| '"' + s }
    end

    def macro(name, *args)
      "\\#{name}" + args.map {|a| "{#{a}}" }.join('')
    end

  end

end
