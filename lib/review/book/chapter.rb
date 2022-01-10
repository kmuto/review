#
# Copyright (c) 2009-2019 Minero Aoki, Kenshi Muto
#               2002-2008 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
require 'review/book/book_unit'
require 'review/lineinput'
require 'review/preprocessor'

module ReVIEW
  module Book
    class Chapter < BookUnit
      attr_reader :number, :book

      def self.mkchap(book, name, number = nil)
        name += book.ext if File.extname(name).empty?
        path = File.join(book.contentdir, name)
        raise FileNotFound, "file not exist: #{path}" unless File.file?(path)

        Chapter.new(book, number, name, path)
      end

      def self.mkchap_ifexist(book, name, number = nil)
        name += book.ext if File.extname(name).empty?
        path = File.join(book.contentdir, name)
        if File.file?(path)
          Chapter.new(book, number, name, path)
        end
      end

      def initialize(book, number, name, path, io = nil)
        @book = book
        @number = number
        @name = name
        @path = path
        @io = io
        @title = nil
        if @io
          begin
            @content = @io.read
          rescue StandardError
            @content = nil
          end
        else
          @content = nil
        end
        if !@content && @path && File.exist?(@path)
          @content = File.read(@path, mode: 'rt:BOM|utf-8')
          @number = nil if %w[nonum nodisp notoc].include?(find_first_header_option)
        end

        super()
      end

      def generate_indexes
        super

        return unless content

        @numberless_image_index = @indexes.numberless_image_index
        @image_index = @indexes.image_index
        @icon_index = @indexes.icon_index
        @indepimage_index = @indexes.indepimage_index
      end

      def find_first_header_option
        f = LineInput.new(StringIO.new(@content))
        begin
          while f.next?
            case f.peek
            when /\A=+[\[\s{]/
              m = /\A(=+)(?:\[(.+?)\])?(?:\{(.+?)\})?(.*)/.match(f.gets)
              return m[2] # tag
            when %r{/\A//[a-z]+/}
              line = f.gets
              if line.rstrip[-1, 1] == '{'
                f.until_match(%r{\A//\}})
              end
            end
            f.gets
          end
          nil
        rescue ArgumentError => e
          raise ReVIEW::CompileError, "#{@name}: #{e}"
        rescue SyntaxError => e
          raise ReVIEW::SyntaxError, "#{@name}:#{f.lineno}: #{e}"
        end
      end

      def inspect
        "#<#{self.class} #{@number} #{@path}>"
      end

      def format_number(heading = true)
        return '' unless @number
        if on_predef?
          return @number.to_s
        end

        if on_appendix?
          # XXX: should be extracted with magic number
          if @number < 1 || @number > 27
            return @number.to_s
          end
          if @book.config['appendix_format']
            raise ReVIEW::ConfigError, %Q('appendix_format:' in config.yml is obsoleted.)
          end

          i18n_appendix = I18n.get('appendix')
          fmt = i18n_appendix.scan(/%\w{1,3}/).first || '%s'
          I18n.update('appendix_without_heading' => fmt)

          if heading
            return I18n.t('appendix', @number)
          else
            return I18n.t('appendix_without_heading', @number)
          end
        end

        if heading
          I18n.t('chapter', @number)
        else
          @number.to_s
        end
      end

      def on_chaps?
        on_file?(@book.read_chaps)
      end

      def on_predef?
        on_file?(@book.read_predef)
      end

      def on_appendix?
        on_file?(@book.read_appendix)
      end

      def on_postdef?
        on_file?(@book.read_postdef)
      end

      private

      def on_file?(contents)
        contents.map(&:strip).include?("#{id}#{@book.ext}")
      end

      # backward compatibility
      alias_method :on_CHAPS?, :on_chaps?
      alias_method :on_PREDEF?, :on_predef?
      alias_method :on_APPENDIX?, :on_appendix?
      alias_method :on_POSTDEF?, :on_postdef?
      alias_method :on_FILE?, :on_file?
    end
  end
end
