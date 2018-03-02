require 'logger'

module ReVIEW
  class Logger < ::Logger
    def initialize(*logdev)
      if logdev.empty?
        super(STDERR, formatter: ->(severity, _datetime, _progname, msg) { "#{severity}: #{msg}\n" })
      else
        super
      end
    end
  end

  def self.logger
    return @logger if @logger

    @logger = ReVIEW::Logger.new
    @logger.formatter = ->(severity, _datetime, _progname, msg) {
      "#{severity}: #{msg}\n"
    }
    @logger
  end

  def self.logger=(logger)
    @logger = logger
  end
end
