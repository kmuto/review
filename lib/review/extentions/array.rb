class Array

  # for ReVIEW::Node
  #
  def to_doc
    self.map(&:to_doc).join("")
  end

  # for ReVIEW::Node
  #
  def to_raw
    self.map(&:to_raw).join("")
  end

  if [].map.kind_of?(Array)
    # Ruby 1.8
    def map(&block)
      if !block_given?
        return to_enum :map
      else
        collect(&block) ## XXX same as original
      end
    end
  end
end
