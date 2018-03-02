require 'test_helper'
require 'review/logger'

class LoggerTest < Test::Unit::TestCase
  def setup
  end

  def test_logging
    old_stderr = STDERR.dup
    IO.pipe do |r, w|
      STDERR.reopen(w)
      @logger = ReVIEW::Logger.new
      @logger.warn("test")
      msg = r.readline
      STDERR.reopen(old_stderr)

      assert_equal "WARN: test\n", msg
    end
  end

end
