# -*- coding: utf-8 -*-
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'review/builder'
require 'review/textutils'

module ReVIEW

  class MARKDOWNBuilder < Builder
    include TextUtils

    def extname
      '.md'
    end

    def puts(str)
      @blank_seen = false
      super
    end

    def blank
      @output.puts unless @blank_seen
      @blank_seen = true
    end

    def headline(level, label, caption)
      prefix = "#" * level
      puts "#{prefix} #{caption}"
    end

    def quote(lines)
      blank
      puts split_paragraph(lines).map{|line| "> #{line}"}.join("\n> \n")
      blank
    end

    def paragraph(lines)
      puts lines.join
      puts "\n"
    end

    def ul_begin
      blank
    end

    def ul_item(lines)
      puts "- #{lines.join}"
    end

    def ul_end
      blank
    end

    def ol_begin
      blank
    end

    def ol_item(lines, num)
      puts "#{num}. #{lines.join}"
    end

    def ol_end
      blank
    end

    def emlist(lines, caption = nil)
      blank
      puts "```"
      lines.each do |line|
        puts detab(line)
      end
      puts "```"
      blank
    end

    def hr
      puts "----"
    end

    def compile_href(url, label)
      label = url if label.blank?
      "[#{label}](#{url})"
    end

    def inline_i(str)
      "*#{str.gsub(/\*/, '\*')}*"
    end

    def inline_b(str)
      "**#{str.gsub(/\*/, '\*')}**"
    end

    def inline_code(str)
      "`#{str}`"
    end

    def image_image(id, caption, metric)
      blank
      puts "![#{caption}](/images/#{id}.#{image_ext})"
      blank
    end

    def image_dummy(id, caption, lines)
      puts lines.join
    end

    def inline_img(id)
      "#{I18n.t("image")}#{@chapter.image(id).number}"
    rescue KeyError
      error "unknown image: #{id}"
      nofunc_text("[UnknownImage:#{id}]")
    end

    def pagebreak
      puts "{pagebreak}"
    end

    def image_ext
      "jpg"
    end

    def nofunc_text(str)
      str
    end
  end

end   # module ReVIEW
