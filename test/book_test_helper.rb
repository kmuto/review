require 'test_helper'
require 'review/book'

require 'stringio'
require 'tempfile'
require 'tmpdir'

include ReVIEW

module BookTestHelper
  def mktmpbookdir(files = {})
    created_files = {}
    Dir.mktmpdir do |tmpdir|
      Dir.chdir(tmpdir) do
        dir = '.'
        files.each_pair do |basename, content|
          path = File.join(dir, basename)
          File.open(path, 'w') { |o| o.print content }
          created_files[basename] = path
        end
        book = Book::Base.load(dir)
        yield(dir, book, created_files)
      end
    end
  end

  def get_instance_variables(obj)
    obj.instance_variables.each_with_object({}) do |name, memo|
      value = obj.instance_variable_get(name)
      if value.instance_variables.empty?
        memo[name] = value
      else
        memo[name] = get_instance_variables(value)
      end
    end
  end
end
