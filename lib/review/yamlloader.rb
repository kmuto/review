require 'yaml'

module ReVIEW
  class YAMLLoader
    def initialize
    end

    def load_file(yamlfile)
      current_file = yamlfile
      loaded_files = {}
      yaml = {}

      loop do
        current_yaml = YAML.load_file(current_file)
        yaml = current_yaml.deep_merge(yaml)

        # Check exit condition
        if !yaml.key?('inherit')
          return yaml
        end

        inherit_file = File.expand_path(yaml['inherit'], File.dirname(yamlfile))

        # Check loop
        if loaded_files[inherit_file]
          raise "Found cyclic YAML inheritance '#{inherit_file}' in #{yamlfile}."
        end

        loaded_files[inherit_file] = true
        yaml.delete('inherit')
        current_file = inherit_file
      end
    end
  end
end
