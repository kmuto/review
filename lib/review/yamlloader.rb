# frozen_string_literal: true

require 'yaml'
require 'date'

module ReVIEW
  class YAMLLoader
    def self.safe_load_file(file)
      if YAML.respond_to?(:safe_load_file)
        YAML.safe_load_file(file, aliases: true, permitted_classes: [Date])
      else
        File.open(file, 'rt:bom|utf-8') do |f|
          begin
            # < Ruby 3.1
            YAML.safe_load(f, filename: file, aliases: true, permitted_classes: [Date])
          rescue ArgumentError
            # < Ruby 2.7
            YAML.safe_load(f, [Date])
          rescue Psych::DisallowedClass
            # < Ruby 2.5
            # rubocop:disable Style/YAMLFileRead
            YAML.safe_load(File.read(file), [Date])
            # rubocop:enable Style/YAMLFileRead
          end
        end
      end
    end

    def self.safe_load(s)
      if YAML.respond_to?(:safe_load_file)
        YAML.safe_load(s, aliases: true, permitted_classes: [Date])
      else
        begin
          # < Ruby 3.1
          YAML.safe_load(s, aliases: true, permitted_classes: [Date])
        rescue ArgumentError, Psych::DisallowedClass
          # < Ruby 2.7
          YAML.safe_load(s, [Date])
        end
      end
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

      while file_queue.present?
        current_file = file_queue.shift
        current_yaml = YAMLLoader.safe_load_file(current_file)
        if current_yaml.instance_of?(FalseClass) || current_yaml.nil?
          raise "#{File.basename(current_file)} is malformed."
        end

        yaml = current_yaml.deep_merge(yaml)

        if yaml.key?('inherit')
          inherit_files = parse_inherit(yaml, yamlfile, loaded_files)
          file_queue = inherit_files + file_queue
        end
      end

      yaml
    end

    def parse_inherit(yaml, yamlfile, loaded_files)
      files = []

      yaml['inherit'].reverse_each do |item|
        inherit_file = File.expand_path(item, File.dirname(yamlfile))

        # Check loop
        if loaded_files[inherit_file]
          raise "Found circular YAML inheritance '#{inherit_file}' in #{yamlfile}."
        end

        loaded_files[inherit_file] = true
        files << inherit_file
      end

      yaml.delete('inherit')

      files
    end
  end
end
