module ReVIEW
  module Loggable
    attr_reader :logger

    def error(msg, location: nil)
      logger.error(msg, location: location)
    end

    def app_error(msg)
      raise ApplicationError, msg
    end

    def error!(msg, location: nil)
      logger.error(msg, location: location)

      exit 1
    end

    def warn(msg, location: nil)
      logger.warn(msg, location: location)
    end

    def debug(msg, location: nil)
      logger.debug(msg, location: location)
    end
  end
end
