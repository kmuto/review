module ReVIEW::Book
  class PageMetric

    MetricData = Struct.new(:n_lines, :n_columns)

    def PageMetric.a5
      new(46, 80, 30, 74, 1)
    end

    def PageMetric.b5
      new(46, 80, 30, 74, 2)
    end
  
    def initialize(list_lines, list_columns, text_lines, text_columns, page_per_kbyte)
      @list = MetricData.new(list_lines, list_columns)
      @text = MetricData.new(text_lines, text_columns)
      @page_per_kbyte = page_per_kbyte
    end

    attr_reader :list
    attr_reader :text
    attr_reader :page_per_kbyte

  end
end
