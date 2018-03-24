require 'yaml'

module ReVIEW
  class Catalog
    def initialize(file)
      if file.respond_to? :read
        @yaml = YAML.load(file.read)
      else ## as Object
        @yaml = file
      end
      @yaml ||= {}
    end

    def predef
      return '' unless @yaml['PREDEF']
      @yaml['PREDEF'].join("\n")
    end

    def chaps
      return '' unless @yaml['CHAPS']

      @yaml['CHAPS'].map do |entry|
        if entry.is_a?(String)
          entry
        elsif entry.is_a?(Hash)
          entry.values # chaps in a part
        end
      end.flatten.join("\n")
    end

    def parts
      return '' unless @yaml['CHAPS']

      part_list = @yaml['CHAPS'].map do |entry|
        if entry.is_a?(Hash)
          entry.keys
        end
      end

      part_list.flatten.compact.join("\n")
    end

    def replace_part(old_name, new_name)
      @yaml['CHAPS'].map! do |e|
        if e.is_a?(Hash) and (e.keys.first == old_name)
          e = { new_name => e.values.first }
        end
        e
      end
    end

    def parts_with_chaps
      return '' unless @yaml['CHAPS']
      @yaml['CHAPS'].flatten.compact
    end

    def appendix
      return '' unless @yaml['APPENDIX']
      @yaml['APPENDIX'].join("\n")
    end

    def postdef
      return '' unless @yaml['POSTDEF']
      @yaml['POSTDEF'].join("\n")
    end

    def to_s
      YAML.dump(@yaml).gsub(/\A---\n/, '') # remove yaml header
    end

    def validate!(config, basedir)
      filenames = []
      if predef.present?
        filenames.concat(predef.split(/\n/))
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
        filenames.concat(appendix.split(/\n/))
      end
      if postdef.present?
        filenames.concat(postdef.split(/\n/))
      end
      filenames.each do |filename|
        refile = File.join(basedir, config['contentdir'], filename)
        unless File.exist?(refile)
          raise FileNotFound, "file not found in catalog.yml: #{refile}"
        end
      end
    end
  end
end
