module ReVIEW::Book
  class ChapterSet

    def ChapterSet.for_argv
      if ARGV.empty?
        new([Chapter.for_stdin])
      else
        for_pathes(ARGV)
      end
    end

    def ChapterSet.for_pathes(pathes)
      new(Chapter.intern_pathes(pathes))
    end

    def initialize(chapters)
      @chapters = chapters
    end

    def no_part?
      true
    end

    attr_reader :chapters

    def each_chapter(&block)
      @chapters.each(&block)
    end

    def ext
      '.re'
    end
  end
end
