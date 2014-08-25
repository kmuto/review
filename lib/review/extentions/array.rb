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
end
