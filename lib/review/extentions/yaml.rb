def YAML.review_load_file(file)
  if YAML.methods.include?(:safe_load_file)
    self.safe_load_file(file, aliases: true, permitted_classes: [Date])
  else
    # Psych backward compatibility
    self.load_file(file)
  end
end
