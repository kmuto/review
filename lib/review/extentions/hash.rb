class Hash
  def deep_merge!(other)
    self.merge!(other) do |key, v_self, v_other|
      if v_self.kind_of?(Hash) && v_other.kind_of?(Hash)
        v_self.deep_merge(v_other)
      else
        v_other
      end
    end
  end

  def deep_merge(other)
    self.dup.deep_merge!(other)
  end
end
