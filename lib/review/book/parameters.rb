#
# $Id: book.rb 4315 2009-09-02 04:15:24Z kmuto $
#
# Copyright (c) 2002-2008 Minero Aoki
#               2009 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
module ReVIEW
  module Book
    class Parameters

      def Parameters.get_page_metric(mod)
        if paper = const_get_safe(mod, :PAPER)
          unless PageMetric.respond_to?(paper.downcase)
            raise ConfigError, "unknown paper size: #{paper}"
          end
          return PageMetric.send(paper.downcase)
        end
        PageMetric.new(const_get_safe(mod, :LINES_PER_PAGE_list) || 46,
          const_get_safe(mod, :COLUMNS_list)        || 80,
          const_get_safe(mod, :LINES_PER_PAGE_text) || 30,
          const_get_safe(mod, :COLUMNS_text)        || 74,  # 37zw
          const_get_safe(mod, :PAGE_PER_KBYTE)         ||  1)  # 37zw
      end

      def Parameters.const_get_safe(mod, name)
        return nil unless mod.const_defined?(name)
        mod.const_get(name)
      end
      private_class_method :const_get_safe

      def initialize(params = {})
        @chapter_file = params[:chapter_file] || 'CHAPS'
        @part_file    = params[:part_file]    || 'PART'
        @reject_file  = params[:reject_file]  || 'REJECT'
        @predef_file  = params[:predef_file]  || 'PREDEF'
        @postdef_file = params[:postdef_file] || 'POSTDEF'
        @page_metric  = params[:page_metric]  || PageMetric.a5
        @ext          = params[:ext]          || '.re'
        @image_dir    = params[:image_dir]    || 'images'
        @image_types  = unify_exts(params[:image_types]  ||
          %w( ai psd eps pdf tif tiff png bmp jpg jpeg gif svg ))
        @bib_file  = params[:bib_file]        || "bib#{@ext}"
      end

      def unify_exts(list)
        list.map {|ext| (ext[0] == '.') ? ext : ".#{ext}" }
      end
      private :unify_exts

      def self.path_param(name)
        module_eval(<<-End, __FILE__, __LINE__ + 1)
        def #{name}
          "\#{@basedir}/\#{@#{name}}"
        end
      End
      end

      path_param  :chapter_file
      path_param  :part_file
      path_param  :bib_file
      path_param  :reject_file
      path_param  :predef_file
      path_param  :postdef_file
      attr_reader :ext
      path_param  :image_dir
      attr_accessor :image_types
      attr_reader :page_metric

    end
  end
end
