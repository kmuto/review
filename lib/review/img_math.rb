require 'fileutils'
require 'shellwords'

module ReVIEW
  class ImgMath
    def initialize(config, path_name: '_review_math')
      @config = config
      @logger = ReVIEW.logger
      @math_dir = File.join(@config['imagedir'], path_name)
      @math_maps = {}
    end

    def cleanup_mathimg
      if @config['math_format'] == 'imgmath' && Dir.exist?(@math_dir)
        FileUtils.rm_rf(@math_dir)
      end
    end

    def defer_math_image(str, key)
      # for Re:VIEW >3
      @math_maps[key] = str
      File.join(@math_dir, "_gen_#{key}.#{@config['imgmath_options']['format']}")
    end

    def make_math_image(str, key, fontsize = 12)
      # Re:VIEW 2 compatibility

      img_path = File.join(@math_dir, "_gen_#{key}.#{@config['imgmath_options']['format']}")
      Dir.mkdir(@math_dir) unless Dir.exist?(@math_dir)
      fontsize2 = (fontsize * 1.2).round.to_i
      texsrc = <<-EOB
\\documentclass[12pt]{article}
\\usepackage[utf8]{inputenc}
\\usepackage{amsmath}
\\usepackage{amsthm}
\\usepackage{amssymb}
\\usepackage{amsfonts}
\\usepackage{anyfontsize}
\\usepackage{bm}
\\pagestyle{empty}

\\begin{document}
\\fontsize{#{fontsize}}{#{fontsize2}}\\selectfont #{str}
\\end{document}
      EOB
      Dir.mktmpdir do |tmpdir|
        tex_path = File.join(tmpdir, 'tmpmath.tex')
        dvi_path = File.join(tmpdir, 'tmpmath.dvi')
        File.write(tex_path, texsrc)
        cmd = "latex --interaction=nonstopmode --output-directory=#{tmpdir} #{tex_path} && dvipng -T tight -z9 -o #{img_path} #{dvi_path}"
        out, status = Open3.capture2e(cmd)
        unless status.success?
          raise ApplicationError, "latex compile error\n\nError log:\n" + out
        end

        img_path
      end
    end

    def make_math_images
      return if @math_maps.empty?

      Dir.mkdir(@math_dir) unless Dir.exist?(@math_dir)
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

      math_real_dir = File.realpath(@math_dir)
      Dir.mktmpdir do |tmpdir|
        File.open(File.join(tmpdir, '__IMGMATH_BODY__.tex'), 'w') do |f|
          @math_maps.keys.sort.each do |key|
            f.puts "% #{key}"
            f.puts @math_maps[key]
            f.puts '\\clearpage'
            f.puts
          end
        end

        tex_path = File.join(tmpdir, '__IMGMATH__.tex')
        File.write(tex_path, texsrc)

        begin
          case @config['imgmath_options']['converter']
          when 'pdfcrop'
            make_math_images_pdfcrop(tmpdir, tex_path, math_real_dir)
          when 'dvipng'
            make_math_images_dvipng(tmpdir, tex_path, math_real_dir)
          else
            error "unknown math converter error. imgmath_options/converter parameter should be 'pdfcrop' or 'dvipng'."
            exit 1
          end
        rescue CompileError
          FileUtils.cp([tex_path,
                        File.join(File.dirname(tex_path), '__IMGMATH__.log')],
                       math_real_dir)
          error "LaTeX math compile error. See #{math_real_dir}/__IMGMATH__.log for details."
          exit 1
        end
      end
      @math_maps.clear
    end

    private

    def error(msg)
      @logger.error msg
    end

    def warn(msg)
      @logger.warn msg
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

    def make_math_images_pdfcrop(dir, tex_path, math_real_dir)
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

        @math_maps.keys.sort.each_with_index do |key, idx|
          page = idx + 1
          if File.exist?(File.join(math_real_dir, "_gen_#{key}.#{@config['imgmath_options']['format']}"))
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
              sub('%t', @config['imgmath_options']['format']).
              sub('%o', File.join(math_real_dir, "_gen_#{key}.#{@config['imgmath_options']['format']}")).
              sub('%O', File.join(math_real_dir, "_gen_#{key}")).
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

    def make_math_images_dvipng(dir, tex_path, math_real_dir)
      Dir.chdir(dir) do
        dvi_path = '__IMGMATH__.dvi'
        out, status = Open3.capture2e(*[@config['texcommand'], @config['texoptions'].shellsplit, tex_path].flatten.compact)
        if !status.success? || !File.exist?(dvi_path)
          raise CompileError
        end

        @math_maps.keys.sort.each_with_index do |key, idx|
          page = idx + 1
          args = @config['imgmath_options']['dvipng_cmd'].shellsplit
          args.map! do |m|
            m.sub('%i', dvi_path).
              sub('%o', File.join(math_real_dir, "_gen_#{key}.#{@config['imgmath_options']['format']}")).
              sub('%O', File.join(math_real_dir, "_gen_#{key}")).
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
