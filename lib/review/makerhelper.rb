# Copyright (c) 2012-2018 Yuto HAYAMIZU, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
require 'pathname'
require 'fileutils'
require 'yaml'
require 'shellwords'

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

            exts = options[:exts] || %w[png gif jpg jpeg svg pdf eps ai tif psd]
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

    def cleanup_mathimg
      math_dir = "./#{@config['imagedir']}/_review_math"
      if @config['imgmath'] && Dir.exist?(math_dir)
        FileUtils.rm_rf(math_dir)
      end
    end

    def default_imgmath_preamble
      <<-EOB
\\documentclass[uplatex,a3paper,landscape]{jsarticle}
\\usepackage[deluxe,uplatex]{otf}
\\usepackage[T1]{fontenc}
\\usepackage{textcomp}
\\usepackage{lmodern}
\\usepackage[dvipdfmx]{graphicx}
\\usepackage[dvipdfmx,table]{xcolor}
\\usepackage[utf8]{inputenc}
\\usepackage{ascmac}
\\usepackage{float}
\\usepackage{alltt}
\\usepackage{amsmath}
\\usepackage{amssymb}
\\usepackage{amsfonts}
\\usepackage{anyfontsize}
\\usepackage{bm}
\\pagestyle{empty}
% \\setpaperwidth{1000mm}
    EOB
    end

    def make_math_images(math_dir)
      fontsize = @config['imgmath_options']['fontsize'].to_f
      lineheight = @config['imgmath_options']['lineheight'].to_f

      texsrc = default_imgmath_preamble
      if @config['imgmath_options']['preamble_file'] && File.readable?(@config['imgmath_options']['preamble_file'])
        texsrc = File.read(@config['imgmath_options']['preamble_file'])
      end

      texsrc << <<-EOB
\\begin{document}
\\fontsize{#{fontsize}}{#{lineheight}}\\selectfont
\\input{__IMGMATH_BODY__}
\\end{document}
EOB

      math_dir = File.realpath(math_dir)
      Dir.mktmpdir do |tmpdir|
        FileUtils.cp([File.join(math_dir, '__IMGMATH_BODY__.tex'),
                      File.join(math_dir, '__IMGMATH_BODY__.map')],
                     tmpdir)
        tex_path = File.join(tmpdir, '__IMGMATH__.tex')
        File.write(tex_path, texsrc)

        begin
          case @config['imgmath_options']['converter']
          when 'pdfcrop'
            make_math_images_pdfcrop(tmpdir, tex_path, math_dir)
          when 'dvipng'
            make_math_images_dvipng(tmpdir, tex_path, math_dir)
          else
            error "unknown math converter error. imgmath_options/converter parameter should be 'pdfcrop' or 'dvipng'."
          end
        rescue CompileError
          FileUtils.cp([tex_path,
                        File.join(File.dirname(tex_path), '__IMGMATH__.log')],
                       math_dir)
          error "LaTeX math compile error. See #{math_dir}/__IMGMATH__.log for details."
        end
      end
      FileUtils.rm_f([File.join(math_dir, '__IMGMATH_BODY__.tex'),
                      File.join(math_dir, '__IMGMATH_BODY__.map')])
    end

    def make_math_images_pdfcrop(dir, tex_path, math_dir)
      Dir.chdir(dir) do
        dvi_path = '__IMGMATH__.dvi'
        pdf_path = '__IMGMATH__.pdf'
        out, status = Open3.capture2e(*[@config['texcommand'], @config['texoptions'].shellsplit, tex_path].flatten.compact)
        if !status.success? || (!File.exist?(dvi_path) && !File.exist?(pdf_path))
          raise CompileError
        end
        if File.exist?(dvi_path)
          out, status = Open3.capture2e(*[@config['dvicommand'], @config['dvioptions'].shellsplit, dvi_path].flatten.compact)
          if !status.success? || !File.exist?(pdf_path)
            warn "error in #{@config['dvicommand']}. Error log:\n#{out}"
            raise CompileError
          end
        end

        args = @config['imgmath_options']['pdfcrop_cmd'].shellsplit
        args.map! do |m|
          m.sub('%i', pdf_path).
            sub('%o', '__IMGMATH__pdfcrop.pdf')
        end
        out, status = Open3.capture2e(*args)
        unless status.success?
          warn "error in pdfcrop. Error log:\n#{out}"
          raise CompileError
        end
        pdf_path = '__IMGMATH__pdfcrop.pdf'
        pdf_path2 = pdf_path

        File.open('__IMGMATH_BODY__.map') do |f|
          page = 0
          f.each_line do |key|
            page += 1
            key.chomp!
            if File.exist?(File.join(math_dir, "_gen_#{key}.#{@config['imgmath_options']['format']}"))
              # made already
              next
            end

            if @config['imgmath_options']['extract_singlepage']
              # if extract_singlepage = true, split each page
              args = @config['imgmath_options']['pdfextract_cmd'].shellsplit

              args.map! do |m|
                m.sub('%i', pdf_path).
                  sub('%o', "__IMGMATH__pdfcrop_p#{page}.pdf").
                  sub('%O', "__IMGMATH__pdfcrop_p#{page}").
                  sub('%p', page.to_s)
              end
              out, status = Open3.capture2e(*args)
              unless status.success?
                warn "error in pdf extracting. Error log:\n#{out}"
                raise CompileError
              end

              pdf_path2 = "__IMGMATH__pdfcrop_p#{page}.pdf"
            end

            args = @config['imgmath_options']['pdfcrop_pixelize_cmd'].shellsplit
            args.map! do |m|
              m.sub('%i', pdf_path2).
                sub('%o', File.join(math_dir, "_gen_#{key}.#{@config['imgmath_options']['format']}")).
                sub('%O', File.join(math_dir, "_gen_#{key}")).
                sub('%p', page.to_s)
            end
            out, status = Open3.capture2e(*args)
            unless status.success?
              warn "error in pdf pixelizing. Error log:\n#{out}"
              raise CompileError
            end
          end
        end
      end
    end

    def make_math_images_dvipng(dir, tex_path, math_dir)
      Dir.chdir(dir) do
        dvi_path = '__IMGMATH__.dvi'
        out, status = Open3.capture2e(*[@config['texcommand'], @config['texoptions'].shellsplit, tex_path].flatten.compact)
        if !status.success? || !File.exist?(dvi_path)
          raise CompileError
        end

        File.open('__IMGMATH_BODY__.map') do |f|
          page = 0
          f.each_line do |key|
            page += 1
            key.chomp!
            args = @config['imgmath_options']['dvipng_cmd'].shellsplit
            args.map! do |m|
              m.sub('%i', dvi_path).
                sub('%o', File.join(math_dir, "_gen_#{key}.#{@config['imgmath_options']['format']}")).
                sub('%O', File.join(math_dir, "_gen_#{key}")).
                sub('%p', page.to_s)
            end
            out, status = Open3.capture2e(*args)
            unless status.success?
              warn "error in dvipng. Error log:\n#{out}"
              raise CompileError
            end
          end
        end
      end
    end
  end
end
