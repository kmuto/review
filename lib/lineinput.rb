#
# $Id: lineinput.rb 2226 2006-04-15 03:05:09Z aamine $
#
# Copyright (c) 2002-2005 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

class LineInput

  def initialize(f)
    @input = f
    @buf = []
    @lineno = 0
    @eof_p = false
  end

  def inspect
    "\#<#{self.class} file=#{@input.inspect} line=#{lineno()}>"
  end

  def eof?
    @eof_p
  end

  def lineno
    @lineno
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
    line
  end

  def ungets(line)
    return unless line
    @lineno -= 1
    @buf.push line
    line
  end

  def peek
    line = gets()
    ungets line if line
    line
  end

  def next?
    peek() ? true : false
  end

  def each
    while line = gets()
      yield line
    end
  end

  def while_match(re)
    while line = gets()
      unless re =~ line
        ungets line
        return
      end
      yield line
    end
    nil
  end

  def getlines_while(re)
    buf = []
    while_match(re) do |line|
      buf.push line
    end
    buf
  end

  alias_method :span, :getlines_while # from Haskell

  def until_match(re)
    while line = gets()
      if re =~ line
        ungets line
        return
      end
      yield line
    end
    nil
  end

  def getlines_until(re)
    buf = []
    until_match(re) do |line|
      buf.push line
    end
    buf
  end

  alias_method :break, :getlines_until # from Haskell

  def until_terminator(re)
    while line = gets()
      return if re =~ line # discard terminal line
      yield line
    end
    nil
  end

end
