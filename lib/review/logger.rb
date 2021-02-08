require 'logger'

module ReVIEW
  class Logger < ::Logger
    def initialize(io = $stderr, progname: '--')
      super(io, progname: progname)
      self.formatter = ->(severity, _datetime, name, msg) { "#{severity} #{name}: #{msg}\n" }
    end

    def ttylogger?
      nil
    end
  end

  begin
    require 'tty-logger'
    class TTYLogger < ::TTY::Logger
      def ttylogger?
        true
      end
    end
  rescue LoadError
    nil
  end

  def self.logger(level: 'info')
    if const_defined?(:TTYLogger)
      @logger ||= TTYLogger.new do |config|
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
      @logger ||= ReVIEW::Logger.new($stderr, progname: File.basename($PROGRAM_NAME, '.*'))
    end
  end

  def self.logger=(logger)
    @logger = logger
  end
end
