module ReVIEW
  class Location
    def initialize(filename, f)
      @filename = filename
      @f = f
    end

    attr_reader :filename

    def lineno
      @f.lineno
    end

    def string
      begin
        "#{@filename}:#{@f.lineno}"
      rescue
        "#{@filename}:nil"
      end
    end

    alias to_s string
  end
end
