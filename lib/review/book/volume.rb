# Copyright (c) 2007-2017 Minero Aoki, Kenshi Muto
#               2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
module ReVIEW
  module Book
    class Volume
      def self.count_file(path)
        b = c = l = 0
        File.foreach(path) do |line|
          next if /\A\#@/ =~ line
          text = line.gsub(/\s+/, '')
          b += text.bytesize
          c += text.charsize
          l += 1
        end
        new(b, c, l)
      end

      def self.sum(vols)
        vols.inject(new) { |sum, i| sum + i }
      end

      def self.dummy
        new(-1, -1, -1)
      end

      def initialize(bytes = 0, chars = 0, lines = 0)
        @bytes = bytes
        @chars = chars
        @lines = lines
        @page_per_kbyte = nil
      end

      attr_reader :bytes
      attr_reader :chars
      attr_accessor :lines
      attr_accessor :page_per_kbyte

      def kbytes
        (@bytes.to_f / 1024).ceil
      end

      def page
        (kbytes.to_f / @page_per_kbyte).ceil
      end

      def to_s
        "#{kbytes}KB #{@chars}C #{@lines}L #{page}P"
      end

      def +(other)
        Volume.new(@bytes + other.bytes,
                   @chars + other.chars,
                   @lines + other.lines)
      end
    end
  end
end
