require 'logger'

module ReVIEW
  class Logger < ::Logger
    def initialize(io = $stderr, progname: '--')
      super(io, progname: progname)
      self.formatter = ->(severity, _datetime, name, msg) { "#{severity} #{name}: #{msg}\n" }
    end

    def warn(msg, location: nil)
      if location
        super("#{location}: #{msg}")
      else
        super(msg)
      end
    end

    def error(msg, location: nil)
      if location
        super("#{location}: #{msg}")
      else
        super(msg)
      end
    end

    def debug(msg, location: nil)
      if location
        super("#{location}: #{msg}")
      else
        super(msg)
      end
    end

    def ttylogger?
      nil
    end

    def success(_log)
      # empty (for backward compatibility)
    end
  end

  begin
    require 'tty-logger'
    class TTYLogger < ::TTY::Logger
      def warn(msg, location: nil)
        if location
          super("#{location}: #{msg}")
        else
          super(msg)
        end
      end

      def error(msg, location: nil)
        if location
          super("#{location}: #{msg}")
        else
          super(msg)
        end
      end

      def debug(msg, location: nil)
        if location
          super("#{location}: #{msg}")
        else
          super(msg)
        end
      end

      def ttylogger?
        true
      end
    end
  rescue LoadError
    nil
  end

  def self.logger(level: 'info')
    @logger ||= if const_defined?(:TTYLogger)
                  TTYLogger.new do |config|
                    config.level = level.to_sym
                    config.handlers = [
                      [:console,
                       {
                         styles: {
                           debug: { label: 'DEBUG' },
                           info: { label: 'INFO', color: :magenta },
                           success: { label: 'SUCCESS' },
                           wait: { label: 'WAIT' },
                           warn: { label: 'WARN' },
                           error: { label: 'ERROR' },
                           fatal: { label: 'FATAL' }
                         }
                       }]
                    ]
                  end
                else
                  ReVIEW::Logger.new($stderr, progname: File.basename($PROGRAM_NAME, '.*'))
                end
  end

  def self.logger=(logger)
    @logger = logger
  end
end
