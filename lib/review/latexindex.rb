# Copyright (c) 2017 Minero Aoki, Kenshi Muto
#               2002-2006 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

module ReVIEW
  class LaTeXIndex
    def load(path)
      table = {}
      File.foreach(path) do |line|
        key, value = *line.strip.split(/\t+/, 2)
        table[key.sub(/\A%/, '')] = value
      end
      new(table)
    end

    def initialize(table)
      @table = table
    end

    def [](key)
      @table.fetch(key)
    end
  end
end
