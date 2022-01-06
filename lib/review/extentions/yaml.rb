def YAML.review_load_file(file)
  if YAML.methods.include?(:safe_load_file)
    self.safe_load_file(file, aliases: true, permitted_classes: [Date])
  else
    # Psych backward compatibility
    self.load_file(file)
  end
end

def YAML.review_load(content)
  if YAML.methods.include?(:safe_load_file)
    self.safe_load(content, aliases: true, permitted_classes: [Date])
  else
    # Psych backward compatibility
    self.safe_load(content)
  end
end
