# Copyright (c) 2007-2017 Kenshi Muto
#               2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of LGPL, see the file "COPYING".
#

require 'review/preprocessor'
require 'stringio'

module ReVIEW
  class WrongInput < Error; end

  class Unfold
    # unfold paragraphs and strip preprocessor tags.
    def self.unfold_author_source(s)
      unfold(Preprocessor::Strip.new(StringIO.new(s)))
    end

    def self.unfold(f)
      new.unfold(f)
    end

    def initialize(indent_paragraph = false)
      @indent_paragraph = indent_paragraph
    end

    # unfold(f) -> String
    # unfold(input, output) -> nil
    def unfold(input, output = nil)
      if output
        @output = output
        do_unfold input
        nil
      else
        @output = StringIO.new
        do_unfold input
        @output.string
      end
    end

    private

    ZSPACE = "\241\241".freeze # EUC-JP zen-kaku space

    def do_unfold(input)
      @blank_needed = false
      first = true
      indent = @indent_paragraph ? ZSPACE : ''
      f = LineInput.new(input)
      f.each_line do |line|
        case line
        when /\A\#@/
          raise "must not happen: input includes preproc directive: #{line.inspect}"
        when /\A=/
          if first
            first = false
          else
            blank
          end
          println line
          # blank
        when /\A\s+\*/
          blank
          println line
          skip_block f, /\A\s+\*|\A\s+\S/
          blank
        when /\A\s+\d+\./
          blank
          println line
          skip_block f, /\A\s+\d+\.|\A\s+\S/
          blank
        when /\A:/
          blank
          println line
          skip_block f, /\A:|\A\s+\S/
          blank
        when %r{\A//\w.*\{\s*\z}
          blank
          println line
          f.until_terminator(%r{\A//\}}) do |s|
            println s
          end
          println '//}'
          blank
        when %r{\A//\w}
          blank
          println line
          blank
        when /\A\S/
          if %r{\A//\[} =~ line
            $stderr.puts "warning: #{f.path}:#{f.lineno}: paragraph begin with `//['; missing ReVIEW directive name?"
          end
          flush_blank
          @output.print indent + line.rstrip
          f.until_match(%r{\A\s*\z|\A//\w}) { |s| @output.print s.rstrip }
          @output.puts
        else
          unless line.strip.empty?
            raise WrongInput, "#{f.path}:#{f.lineno}: wrong input: #{line.inspect}"
          end
        end
      end
    end

    def skip_block(f, re)
      f.while_match(re) do |line|
        @output.puts line.rstrip
      end
    end

    def blank
      @blank_needed = true
    end

    def println(s)
      flush_blank
      @output.puts s.rstrip
    end

    def flush_blank
      return unless @blank_needed
      @output.puts
      @blank_needed = false
    end
  end
end # module ReVIEW
