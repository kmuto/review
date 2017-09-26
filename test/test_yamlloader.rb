require 'test_helper'
require 'review/yamlloader'
require 'review/extentions'
require 'tmpdir'

class YAMLLoaderTest < Test::Unit::TestCase
  def setup
    @loader = ReVIEW::YAMLLoader.new
  end

  def teardown
  end

  def test_load_file
    Dir.mktmpdir do |dir|
      yaml_file = File.join(dir, 'test.yml')
      File.open(yaml_file, 'w') do |f|
        f.write <<EOB
foo:
  bar: "test"
EOB
      end
      yaml = @loader.load_file(yaml_file)
      assert_equal yaml, 'foo' => { 'bar' => 'test' }
    end
  end

  def test_load_file_inherit
    Dir.mktmpdir do |dir|
      yaml_file = File.join(dir, 'test.yml')
      yaml_file2 = File.join(dir, 'test2.yml')
      File.open(yaml_file, 'w') do |f|
        f.write <<EOB
k0: 2
k1:
  name: "test"
  array: [{name: "N", val: "V"}]
inherit: ["test2.yml"]
EOB
      end
      File.open(yaml_file2, 'w') do |f|
        f.write <<EOB
k1:
  name: "test2"
  name2: "value2"
  array: [{name: "shoudoverridden_name", val: "shouldoverridden_val"}]
k2: "3"
EOB
      end
      yaml = @loader.load_file(yaml_file)
      assert_equal({ 'k0' => 2,
                     'k1' => { 'name' => 'test', 'name2' => 'value2',
                               'array' => [{ 'name' => 'N', 'val' => 'V' }] },
                     'k2' => '3' },
                   yaml)
    end
  end

  def test_load_file_inherit2
    Dir.mktmpdir do |dir|
      yaml_file = File.join(dir, 'test.yml')
      yaml_file2 = File.join(dir, 'test2.yml')
      yaml_file3 = File.join(dir, 'test3.yml')
      File.open(yaml_file, 'w') do |f|
        f.write <<EOB
k0: 2
k1:
  name1: "value1-1"
inherit: ["test3.yml", "test2.yml"]
EOB
      end
      File.open(yaml_file2, 'w') do |f|
        f.write <<EOB
k1:
  name1: "value1-2"
  name2: "value2-2"
k2: "B"
EOB
      end
      File.open(yaml_file3, 'w') do |f|
        f.write <<EOB
k1:
  name1: "value1-3"
  name2: "value2-3"
  name3: "value3-3"
k3: "C"
EOB
      end
      yaml = @loader.load_file(yaml_file)
      assert_equal({
                     'k0' => 2,
                     'k1' => { 'name1' => 'value1-1', 'name2' => 'value2-2', 'name3' => 'value3-3' },
                     'k2' => 'B',
                     'k3' => 'C'
                   },
                   yaml)
    end
  end

  def test_load_file_inherit3
    Dir.mktmpdir do |dir|
      yaml_file1 = File.join(dir, 'test1.yml')
      yaml_file2 = File.join(dir, 'test2.yml')
      yaml_file3 = File.join(dir, 'test3.yml')
      yaml_file4 = File.join(dir, 'test4.yml')
      yaml_file5 = File.join(dir, 'test5.yml')
      yaml_file6 = File.join(dir, 'test6.yml')
      yaml_file7 = File.join(dir, 'test7.yml')
      File.open(yaml_file7, 'w') do |f|
        f.write <<EOB
k1:
  name1: "N7"
inherit: ["test3.yml", "test6.yml"]
EOB
      end
      File.open(yaml_file6, 'w') do |f|
        f.write <<EOB
k1:
  name1: "N6"
  name2: "N6"
inherit: ["test4.yml", "test5.yml"]
EOB
      end
      File.open(yaml_file5, 'w') do |f|
        f.write <<EOB
k1:
  name1: "N5"
  name2: "N5"
  name3: "N5"
EOB
      end
      File.open(yaml_file4, 'w') do |f|
        f.write <<EOB
k1:
  name1: "N4"
  name2: "N4"
  name3: "N4"
  name4: "N4"
EOB
      end
      File.open(yaml_file3, 'w') do |f|
        f.write <<EOB
k1:
  name1: "N3"
  name2: "N3"
  name3: "N3"
  name4: "N3"
  name5: "N3"
inherit: ["test1.yml", "test2.yml"]
EOB
      end
      File.open(yaml_file2, 'w') do |f|
        f.write <<EOB
k1:
  name1: "N2"
  name2: "N2"
  name3: "N2"
  name4: "N2"
  name5: "N2"
  name6: "N2"
EOB
      end
      File.open(yaml_file1, 'w') do |f|
        f.write <<EOB
k1:
  name1: "N1"
  name2: "N1"
  name3: "N1"
  name4: "N1"
  name5: "N1"
  name6: "N1"
  name7: "N1"
EOB
      end

      yaml = @loader.load_file(yaml_file7)
      assert_equal({ 'k1' => { 'name1' => 'N7',
                               'name2' => 'N6',
                               'name3' => 'N5',
                               'name4' => 'N4',
                               'name5' => 'N3',
                               'name6' => 'N2',
                               'name7' => 'N1' } },
                   yaml)
    end
  end
end
