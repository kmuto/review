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
        files.each_pair do |filename, content|
          path = File.join(dir, filename)
          FileUtils.mkdir_p(File.dirname(path))
          File.open(path, 'w') { |o| o.print content }
          created_files[filename] = path
        end
        conf_path = File.expand_path('config.yml', dir)
        config = if File.exist?(conf_path)
                   ReVIEW::Configure.create(yamlfile: conf_path)
                 else
                   ReVIEW::Configure.values
                 end
        book = Book::Base.new(dir, config: config)
        yield(dir, book, created_files)
      end
    end
  end

  def get_instance_variables(obj)
    obj.instance_variables.each_with_object({}) do |name, memo|
      value = obj.instance_variable_get(name)
      memo[name] = if value.instance_variables.empty?
                     value
                   else
                     get_instance_variables(value)
                   end
    end
  end
end
