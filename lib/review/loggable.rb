module ReVIEW
  module Loggable
    attr_reader :logger

    def error(msg, location: nil)
      logger.error(msg, location: location)
    end

    def error!(msg, location: nil, exception: nil)
      logger.error(msg, location: location)

      if exception
        raise exception, msg
      else
        exit 1
      end
    end

    def warn(msg, location: nil)
      logger.warn(msg, location: location)
    end

    def debug(msg, location: nil)
      logger.debug(msg, location: location)
    end
  end
end
