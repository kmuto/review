unless String.method_defined?(:lines)
  # Ruby 1.8
  class String
    alias lines to_a
  end
end

if String.method_defined?(:bytesize)
  # Ruby 1.9
  class String
    alias charsize size
  end
else
  # Ruby 1.8
  class String
    alias bytesize size

    def charsize
      split(//).size
    end
  end
end
