require 'test_helper'
require 'review/yamlloader'

class YAMLLoaderTest < Test::Unit::TestCase
  def setup
    @loader = ReVIEW::YAMLLoader.new
  end

  def teardown
  end

  def test_load_file
    Dir.mktmpdir do |dir|
      yaml_file = File.join(dir, "test.yml")
      File.open(yaml_file, "w") do |f|
        f.write <<EOB
foo:
  bar: "test"
EOB
      end
      yaml = @loader.load_file(yaml_file)
      assert_equal yaml, {"foo" => {"bar"=>"test"}}
    end
  end

  def test_load_file_inherit
    Dir.mktmpdir do |dir|
      yaml_file = File.join(dir, "test.yml")
      yaml_file2 = File.join(dir, "test2.yml")
      File.open(yaml_file, "w") do |f|
        f.write <<EOB
k0: 2
k1:
  name: "test"
inherit: "test2.yml"
EOB
      end
      File.open(yaml_file2, "w") do |f|
        f.write <<EOB
k1:
  name: "test2"
  name2: "value2"
k2: "3"
EOB
      end
      yaml = @loader.load_file(yaml_file)
      assert_equal({"k0"=>2,
                    "k1" => {"name"=>"test", "name2"=>"value2"},
                    "k2" => "3"},
                   yaml)
    end
  end
end
