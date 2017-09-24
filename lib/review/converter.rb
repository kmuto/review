# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#

module ReVIEW
  class Converter
    attr_accessor :target

    def initialize(book, builder)
      @book = book
      @book.config['builder'] = builder.target_name
      @compiler = ReVIEW::Compiler.new(builder)
    end

    def convert(file, output_path)
      chap_name = File.basename(file, '.*')
      chap = @book.chapter(chap_name)
      result = @compiler.compile(chap)
      File.open(output_path, 'w') { |f| f.puts result }
    end
  end
end
