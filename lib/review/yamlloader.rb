require 'yaml'

module ReVIEW
  class YAMLLoader
    def initialize
    end

    # load YAML files
    #
    # `inherit: [3.yml, 6.yml]` in 7.yml; `inherit: [1.yml, 2.yml]` in 3.yml; `inherit: [4.yml, 5.yml]` in 6.yml
    #    => 7.yml > 6.yml > 5.yml > 4.yml > 3.yml > 2.yml > 1.yml
    #
    def load_file(yamlfile)
      file_queue = [File.expand_path(yamlfile)]
      loaded_files = {}
      yaml = {}

      loop do
        # Check exit condition
        return yaml if file_queue.empty?

        current_file = file_queue.shift
        current_yaml = YAML.load_file(current_file)
        yaml = current_yaml.deep_merge(yaml)

        next unless yaml.key?('inherit')

        buf = []
        yaml['inherit'].reverse_each do |item|
          inherit_file = File.expand_path(item, File.dirname(yamlfile))

          # Check loop
          if loaded_files[inherit_file]
            raise "Found circular YAML inheritance '#{inherit_file}' in #{yamlfile}."
          end

          loaded_files[inherit_file] = true
          buf << inherit_file
        end
        yaml.delete('inherit')
        file_queue = buf + file_queue
      end
    end
  end
end
