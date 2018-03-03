# Copyright (c) 2010-2017 Kenshi Muto and Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'pathname'
begin
  require 'zip'
rescue LoadError
  ## I cannot find rubyzip library, so I use external zip command.
  warn 'rubyzip not found, so use external zip command'
end

module EPUBMaker
  ##
  # Export into zip file for EPUB producer.
  #
  class ZipExporter
    attr_reader :tmpdir

    def initialize(tmpdir, config)
      @tmpdir = tmpdir
      @config = config
    end

    def export_zip(epubfile)
      if defined?(Zip)
        export_zip_rubyzip(epubfile)
      else
        export_zip_extcmd(epubfile)
      end
    end

    def export_zip_extcmd(epubfile)
      stage1 = @config['epubmaker']['zip_stage1'].to_s.split
      path1 = stage1[0] || 'zip'
      opt1 = stage1[1] || '-0Xq'
      stage2 = @config['epubmaker']['zip_stage2'].to_s.split
      path2 = stage2[0] || 'zip'
      opt2 = stage2[1] || '-Xr9Dq'

      Dir.chdir(tmpdir) do
        system(path1, opt1, epubfile, 'mimetype')
        addpath = @config['epubmaker']['zip_addpath']
        if addpath
          system(path2, opt2, epubfile, 'META-INF', 'OEBPS', addpath)
        else
          system(path2, opt2, epubfile, 'META-INF', 'OEBPS')
        end
      end
    end

    def export_zip_rubyzip(epubfile)
      Dir.chdir(tmpdir) do
        Zip::OutputStream.open(epubfile) do |epub|
          root_pathname = Pathname.new(tmpdir)
          epub.put_next_entry('mimetype', nil, nil, Zip::Entry::STORED)
          epub << 'application/epub+zip'

          export_zip_rubyzip_addpath(epub, File.join(tmpdir, 'META-INF'), root_pathname)
          export_zip_rubyzip_addpath(epub, File.join(tmpdir, 'OEBPS'), root_pathname)
          if @config['zip_addpath'].present?
            export_zip_rubyzip_addpath(epub, File.join(tmpdir, @config['zip_addpath']), root_pathname)
          end
        end
      end
    end

    def export_zip_rubyzip_addpath(epub, dirname, rootdir)
      Dir[File.join(dirname, '**', '**')].each do |path|
        next if File.directory?(path)
        relpath = Pathname.new(path).relative_path_from(rootdir)
        epub.put_next_entry(relpath)
        epub << File.binread(path)
      end
    end
  end
end
