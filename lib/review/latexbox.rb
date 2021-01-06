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
      stys = []

      %w[column note memo tip info warning important caution notice].each do |name|
        if config['pdfmaker']['boxsetting'][name].nil? || config['pdfmaker']['boxsetting'][name]['style'].nil?
          next
        end

        begin
          # call box_*(config, name) to get begin/end environment string.
          sty, beginenv, endenv = send("box_#{config['pdfmaker']['boxsetting'][name]['style']}", config, name)
        rescue NoMethodError
          raise ReVIEW::ConfigError, "Undefined box style '#{config['pdfmaker']['boxsetting'][name]['style']}' for '#{name}'."
        rescue ReVIEW::ConfigError => e
          # config error raised from box method.
          raise ReVIEW::ConfigError, e
        end

        unless stys.include?(sty)
          stys.push(sty)
        end

        endenv ||= %Q(\\end{#{config['pdfmaker']['boxsetting'][name]['style']}})
        ret << <<EOT
\\renewenvironment{review#{name}}[1][]{%
 #{beginenv}}{%
 #{endenv}}
EOT
      end

      stys.map! do |sty|
        if sty =~ /\[/ # with sty option
          %Q(\\usepackage#{sty})
        else
          %Q(\\usepackage{#{sty}})
        end
      end

      stys.join("\n") + "\n" + ret
    end

    # ascolorbox styles
    def box_simplesquarebox(config, name)
      unless config['pdfmaker']['boxsetting'][name]['thickness']
        config['pdfmaker']['boxsetting'][name]['thickness'] = 0.5
      end
      ['ascolorbox', %Q(\\begin{simplesquarebox}{##1}[#{config['pdfmaker']['boxsetting'][name]['thickness']}][#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_practicebox(config, name)
      ['ascolorbox', %Q(\\begin{practicebox}{##1}[#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox1(config, name)
      ['ascolorbox', %Q(\\begin{ascolorbox1}{##1}[#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox2(config, name)
      ['ascolorbox', %Q(\\begin{ascolorbox2}{##1}[#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox3(config, name)
      ['ascolorbox', %Q(\\begin{ascolorbox3}{##1}[#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox4(config, name)
      unless config['pdfmaker']['boxsetting'][name]['length']
        config['pdfmaker']['boxsetting'][name]['length'] = 2
      end
      ['ascolorbox', %Q(\\begin{ascolorbox4}{##1}[#{config['pdfmaker']['boxsetting'][name]['length']}][#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox5(config, name)
      unless config['pdfmaker']['boxsetting'][name]['color']
        config['pdfmaker']['boxsetting'][name]['color'] = 'black'
      end
      ['ascolorbox', %Q(\\begin{ascolorbox5}{##1}[#{config['pdfmaker']['boxsetting'][name]['color']}][#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox8(config, name)
      ['ascolorbox', %Q(\\begin{ascolorbox8}{##1}[#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox9(config, name)
      unless config['pdfmaker']['boxsetting'][name]['number']
        config['pdfmaker']['boxsetting'][name]['number'] = 3
      end
      ['ascolorbox', %Q(\\begin{ascolorbox9}{##1}[#{config['pdfmaker']['boxsetting'][name]['number']}][#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox10(config, name)
      unless config['pdfmaker']['boxsetting'][name]['thickness']
        config['pdfmaker']['boxsetting'][name]['thickness'] = 0.8
      end
      ['ascolorbox', %Q(\\begin{ascolorbox10}{##1}[#{config['pdfmaker']['boxsetting'][name]['thickness']}][#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox11(config, name)
      unless config['pdfmaker']['boxsetting'][name]['length']
        config['pdfmaker']['boxsetting'][name]['length'] = 4
      end
      ['ascolorbox', %Q(\\begin{ascolorbox11}{##1}[#{config['pdfmaker']['boxsetting'][name]['length']}][#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox12(config, name)
      ['ascolorbox', %Q(\\begin{ascolorbox12}{##1}[#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox13(config, name)
      ['ascolorbox', %Q(\\begin{ascolorbox13}{##1}[#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox14(config, name)
      ['ascolorbox', %Q(\\begin{ascolorbox14}{##1}[#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox15(config, name)
      ['ascolorbox', %Q(\\begin{ascolorbox15}{##1}[#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox16(config, name)
      ['ascolorbox', %Q(\\begin{ascolorbox16}{##1}[#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox17(config, name)
      unless config['pdfmaker']['boxsetting'][name]['color']
        config['pdfmaker']['boxsetting'][name]['color'] = 'black'
      end
      ['ascolorbox', %Q(\\begin{ascolorbox17}{##1}[#{config['pdfmaker']['boxsetting'][name]['color']}][#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox18(config, name)
      ['ascolorbox', %Q(\\begin{ascolorbox18}{##1}[#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end

    def box_ascolorbox19(config, name)
      unless config['pdfmaker']['boxsetting'][name]['length']
        config['pdfmaker']['boxsetting'][name]['length'] = 2
      end
      ['ascolorbox', %Q(\\begin{ascolorbox19}{##1}[#{config['pdfmaker']['boxsetting'][name]['length']}][#{config['pdfmaker']['boxsetting'][name]['options']}])]
    end
  end
end
