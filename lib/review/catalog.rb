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

      @yaml['CHAPS'].map { |entry| entry.keys if entry.is_a?(Hash) }.flatten.compact.join("\n")
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
  end
end
