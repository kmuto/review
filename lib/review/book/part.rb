module ReVIEW::Book
  class Part

    def initialize(number, chapters, name="")
      @number = number
      @chapters = chapters
      @name = name
    end

    attr_reader :number
    attr_reader :chapters
    attr_reader :name

    def each_chapter(&block)
      @chapters.each(&block)
    end

    def volume
      Volume.sum(@chapters.map {|chap| chap.volume })
    end

  end
end
