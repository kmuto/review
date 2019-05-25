require 'logger'

module ReVIEW
  class Logger < ::Logger
    def initialize(io = STDERR, progname: '--')
      super(io, progname: progname)
      self.formatter = ->(severity, _datetime, name, msg) { "#{severity} #{name}: #{msg}\n" }
    end
  end

  def self.logger
    @logger ||= ReVIEW::Logger.new(STDERR, progname: File.basename($PROGRAM_NAME, '.*'))
  end

  def self.logger=(logger)
    @logger = logger
  end
end
