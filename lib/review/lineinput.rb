# frozen_string_literal: true

#
# Copyright (c) 2002-2023 Minero Aoki, Masayoshi Takahashi, Kenshi Muto
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#
require 'review/exception'
require 'stringio'

module ReVIEW
  class LineInput
    INVALID_CHARACTER_PATTERN = /[\x00-\x08\x0b-\x0c\x0e-\x1f]/ # accept 0x09: TAB, 0x0a: LF, 0x0d: CR

    attr_reader :lineno

    def initialize(f)
      @input = f
      @buf = []
      @lineno = 0
      @eof_p = false
    end

    # Create LineInput from a string directly
    def self.from_string(string)
      new(StringIO.new(string))
    end

    def inspect
      "#<#{self.class} file=#{@input.inspect} line=#{lineno}>"
    end

    def eof?
      @eof_p
    end

    def skip_comment_lines
      n = 0
      while line = gets
        unless /\A\#@/.match?(line.strip)
          ungets(line)
          return n
        end
        n += 1
      end
      n
    end

    def gets
      unless @buf.empty?
        @lineno += 1
        return @buf.pop
      end
      return nil if @eof_p # to avoid ARGF blocking.

      line = @input.gets
      @eof_p = true unless line
      @lineno += 1
      invalid_char = lookup_invalid_char(line)
      if invalid_char
        raise SyntaxError, "found invalid control-sequence character (#{sprintf('%#x', invalid_char.codepoints[0])})."
      end

      line
    end

    def peek
      line = gets
      ungets(line) if line
      line
    end

    def next?
      peek ? true : false
    end

    def skip_blank_lines
      n = 0
      while line = gets
        unless line.strip.empty?
          ungets(line)
          return n
        end
        n += 1
      end
      n
    end

    def each
      while line = gets
        yield line
      end
    end

    def while_match(re)
      while line = gets
        unless re&.match?(line)
          ungets(line)
          return
        end
        yield line
      end
      nil
    end

    def until_match(re)
      while line = gets
        if re&.match?(line)
          ungets(line)
          return
        end
        yield line
      end
      nil
    end

    private

    def ungets(line)
      return unless line

      @lineno -= 1
      @buf.push(line)
      line
    end

    def lookup_invalid_char(line)
      if line =~ INVALID_CHARACTER_PATTERN
        $&
      end
    end
  end
end
