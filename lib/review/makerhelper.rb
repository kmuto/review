# Copyright (c) 2012-2017 Yuto HAYAMIZU, Kenshi Muto
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
  module MakerHelper
    # Return review/bin directory
    def bindir
      Pathname.new("#{Pathname.new(__FILE__).realpath.dirname}/../../bin").realpath
    end
    module_function :bindir

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

    def copy_images_to_dir(from_dir, to_dir, options = {})
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

            exts = options[:exts] || %w[png gif jpg jpeg svg pdf eps ai tif]
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
    module_function :copy_images_to_dir
  end
end
