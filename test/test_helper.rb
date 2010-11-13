$LOAD_PATH.unshift(File.dirname(__FILE__) + '/../lib/')
require 'test/unit'

module TestHelper
  def capture_stdout
    bout = @builder.output
    out = StringIO.new
    @builder.output = out
    yield
    return out
  ensure
    @builder.output = bout
  end
end
