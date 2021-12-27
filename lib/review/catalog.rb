require 'yaml'
require 'date'

module ReVIEW
  class Catalog
    def initialize(file)
      if file.respond_to?(:read)
        @yaml = YAML.safe_load(file.read, permitted_classes: [Date])
      else ## as Object
        @yaml = file
      end
      @yaml ||= {}
    end

    def predef
      @yaml['PREDEF'] || []
    end

    def chaps
      return [] unless @yaml['CHAPS']

      @yaml['CHAPS'].map do |entry|
        if entry.is_a?(String)
          entry
        elsif entry.is_a?(Hash)
          entry.values # chaps in a part
        end
      end.flatten
    end

    def parts
      return [] unless @yaml['CHAPS']

      part_list = @yaml['CHAPS'].map do |entry|
        if entry.is_a?(Hash)
          entry.keys
        end
      end

      part_list.flatten.compact
    end

    def replace_part(old_name, new_name)
      @yaml['CHAPS'].map! do |e|
        if e.is_a?(Hash) && (e.keys.first == old_name)
          e = { new_name => e.values.first }
        end
        e
      end
    end

    def parts_with_chaps
      return [] unless @yaml['CHAPS']

      @yaml['CHAPS'].flatten.compact
    end

    def appendix
      @yaml['APPENDIX'] || []
    end

    def postdef
      @yaml['POSTDEF'] || []
    end

    def to_s
      YAML.dump(@yaml).gsub(/\A---\n/, '') # remove yaml header
    end

    def validate!(config, basedir)
      filenames = []
      if predef.present?
        filenames.concat(predef)
      end
      parts_with_chaps.each do |chap|
        if chap.is_a?(Hash)
          chap.each_key do |part|
            if File.extname(part) == '.re'
              filenames.push(part)
            end
          end
          filenames.concat(chap.values.flatten)
        else
          filenames.push(chap)
        end
      end
      if appendix.present?
        filenames.concat(appendix)
      end
      if postdef.present?
        filenames.concat(postdef)
      end
      filenames.each do |filename|
        refile = File.expand_path(File.join(config['contentdir'], filename), basedir)
        unless File.exist?(refile)
          raise FileNotFound, "file not found in catalog.yml: #{refile}"
        end
      end
    end
  end
end
