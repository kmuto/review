# Copyright (c) 2009-2019 Minero Aoki, Kenshi Muto, Masayoshi Takahashi
# Copyright (c) 2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

module ReVIEW
  class Location
    def initialize(filename, f)
      @filename = filename
      @f = f
    end

    attr_reader :filename

    def lineno
      @f.lineno
    end

    def string
      begin
        "#{@filename}:#{@f.lineno}"
      rescue
        "#{@filename}:nil"
      end
    end

    alias_method :to_s, :string
  end
end
