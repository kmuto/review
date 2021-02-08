# Copyright (c) 2021 Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
require 'review/logger'
module ReVIEW
  class LaTeXBox
    def initialize
      @logger = ReVIEW.logger
    end

    def tcbox(config)
      ret = ''

      %w[column note memo tip info warning important caution notice].each do |name|
        if config['pdfmaker'].nil? || config['pdfmaker']['boxsetting'].nil? ||
           config['pdfmaker']['boxsetting'][name].nil? ||
           config['pdfmaker']['boxsetting'][name]['style'].nil?
          next
        end

        options = '[]'
        options_with_caption = '[]'
        if config['pdfmaker']['boxsetting'][name]['options']
          options = "[#{config['pdfmaker']['boxsetting'][name]['options']}]"
          options_with_caption = options
        end

        if config['pdfmaker']['boxsetting'][name]['options_with_caption']
          options_with_caption = "[#{config['pdfmaker']['boxsetting'][name]['options_with_caption']}]"
        end

        ret << <<EOT
\\renewenvironment{review#{name}}[1][]{%
  \\csdef{rv@tmp@withcaption}{true}
  \\notblank{##1}{
    \\begin{rv@#{config['pdfmaker']['boxsetting'][name]['style']}@caption}{##1}#{options_with_caption}
   }{
    \\csundef{rv@tmp@withcaption}
    \\begin{rv@#{config['pdfmaker']['boxsetting'][name]['style']}@nocaption}#{options}
   }
}{
  \\ifcsdef{rv@tmp@withcaption}{
    \\end{rv@#{config['pdfmaker']['boxsetting'][name]['style']}@caption}
  }{
    \\end{rv@#{config['pdfmaker']['boxsetting'][name]['style']}@nocaption}
  }
}
EOT
      end

      ret
    end
  end
end
