module ReVIEW
  class Location
    def initialize(filename, compiler)
      @filename = filename
      @f = compiler
    end

    attr_reader :filename

    def lineno
      @f.current_line
    end

    def string
      begin
        "#{@filename}:#{self.lineno}"
      rescue
        "#{@filename}:nil"
      end
    end

    alias to_s string
  end
end
