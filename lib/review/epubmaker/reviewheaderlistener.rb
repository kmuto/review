# Copyright (c) 2010-2018 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
module ReVIEW
  class EPUBMaker
    # Listener class to scan HTML and get heading information
    #
    # The heading information this listener will retrieve is as follows:
    #
    # * level: Heading level (1..6)
    # * id: HTMl ID attribute. Basically the `id` attribute of the h(1-6) element, but if there is an `a` element within the h(1-6) element, it will be its `id` attribute.
    # * title: The title string of the headline. Usually, it is the text within the h(1-6) element, but if there is an `img` element, it will be the text with its `alt` attribute.
    # * notoc: The `notoc` attribute of the headline element.
    #
    class ReVIEWHeaderListener
      include REXML::StreamListener
      def initialize(headlines)
        @level = nil
        @content = ''
        @headlines = headlines
      end

      def tag_start(name, attrs)
        if name =~ /\Ah(\d+)/
          raise "#{name}, #{attrs}" if @level.present?

          @level = $1.to_i
          @id = attrs['id'] if attrs['id'].present?
          @notoc = attrs['notoc'] if attrs['notoc'].present?
        elsif @level.present? # if in <hN> tag
          if name == 'img' && attrs['alt'].present?
            @content << attrs['alt']
          elsif name == 'a' && attrs['id'].present?
            @id = attrs['id']
          end
        end
      end

      def tag_end(name)
        if /\Ah\d+/.match?(name)
          if @id.present?
            @headlines.push({ 'level' => @level,
                              'id' => @id,
                              'title' => @content,
                              'notoc' => @notoc })
          end
          @content = ''
          @level = nil
          @id = nil
          @notoc = nil
        end

        true
      end

      def text(text)
        if @level.present?
          @content << text.tr("\t", '　')
        end
      end
    end
  end
end
