if defined?(Encoding) && Encoding.respond_to?('default_external') &&
   Encoding.default_external != Encoding::UTF_8
  Encoding.default_external = 'UTF-8'
end
