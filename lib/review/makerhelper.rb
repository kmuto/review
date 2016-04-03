# encoding: utf-8
#
# Copyright (c) 2012-2016 Yuto HAYAMIZU, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
require 'pathname'
require 'fileutils'
require 'yaml'

module ReVIEW
  class MakerHelper
    # Return review/bin directory
    def self.bindir
      Pathname.new("#{Pathname.new(__FILE__).realpath.dirname}/../../bin").realpath
    end

    # Copy image files under from_dir to to_dir recursively
    # ==== Args
    # from_dir :: path to the directory which has image files to be copied
    # to_dir :: path to the directory to which the image files are copied
    # options :: used to specify optional operations during copy
    # ==== Returns
    # list of image files
    # ==== Options
    # :convert :: Conversion rule
    # ==== Examples
    #
    #   copy_images_to_dir("/path/to/foo", "/path/to/bar", :convert => {:eps => :png})
    #
    # Image files are copied recursively, and each '.eps' file is converted into '.eps.png'
    #

    def self.copy_images_to_dir(from_dir, to_dir, options = {})
      image_files = []

      Dir.open(from_dir) do |dir|
        dir.each do |fname|
          next if fname =~ /^\./
          if FileTest.directory?("#{from_dir}/#{fname}")
            image_files += copy_images_to_dir("#{from_dir}/#{fname}", "#{to_dir}/#{fname}", options)
          else
            FileUtils.mkdir_p(to_dir) unless File.exist?(to_dir)

            is_converted = false
            (options[:convert] || {}).each do |orig_type, conv_type|
              next unless /\.#{orig_type}$/ =~ fname
              is_converted = system("convert #{from_dir}/#{fname} #{to_dir}/#{fname}.#{conv_type}")
              image_files << "#{from_dir}/#{fname}.#{conv_type}"
            end

            exts = options[:exts] || %w(png gif jpg jpeg svg pdf eps)
            exts_str = exts.join('|')
            if !is_converted && fname =~ /\.(#{exts_str})$/i
              FileUtils.cp "#{from_dir}/#{fname}", to_dir
              image_files << "#{from_dir}/#{fname}"
            end
          end
        end
      end

      image_files
    end

    def self.recursive_load_yaml(yamlfile)
      __recursive_load_yaml({}, yamlfile, {})[0]
    end

    private
    def self.__recursive_load_yaml(yaml, yamlfile, loaded_yaml={})
      _yaml = YAML.load_file(yamlfile)
      yaml = _yaml.merge(yaml)
      if yaml['inherit']
        inheritfile = yaml['inherit']
        
        # Check loop
        if loaded_yaml[inheritfile]
          raise "Found cyclic YAML inheritance '#{inheritfile}' in #{yamlfile}."
        else
          loaded_yaml[inheritfile] = true
        end
        
        yaml.delete('inherit')
        yaml, loaded_yaml = self.__recursive_load_yaml(yaml, inheritfile, loaded_yaml)
      end
      return yaml, loaded_yaml
    end
  end
end
