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
    @logger ||= ReVIEW::Logger.new
  end

  def self.logger=(logger)
    @logger = logger
  end
end
