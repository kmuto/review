# Copyright (c) 2010-2018 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
module ReVIEW
  class EPUBMaker
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
        elsif !@level.nil?
          if name == 'img' && attrs['alt'].present?
            @content << attrs['alt']
          elsif name == 'a' && attrs['id'].present?
            @id = attrs['id']
          end
        end
      end

      def tag_end(name)
        if name =~ /\Ah\d+/
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
