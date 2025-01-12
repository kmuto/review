# frozen_string_literal: true

#
# Copyright (c) 2012-2022 Masanori Kado, Masayoshi Takahashi, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
require 'securerandom'
require 'review/yamlloader'

module ReVIEW
  class Configure < Hash
    attr_accessor :maker

    def self.values # rubocop:disable Metrics/MethodLength
      conf = Configure[
        # These parameters can be overridden by YAML file.
        'bookname' => 'book', # it defines epub file name also
        'booktitle' => 'Re:VIEW Sample Book',
        'title' => nil,
        'aut' => nil, # author
        'prt' => nil, # printer(publisher)
        'asn' => nil, # associated name
        'ant' => nil, # bibliographic antecedent
        'clb' => nil, # Collaborator
        'edt' => nil, # Editor
        'dsr' => nil, # Designer
        'ill' => nil, # Illustrator
        'pht' => nil, # Photographer
        'trl' => nil, # Translator
        'date' => Time.now.strftime('%Y-%m-%d'), # publishing date
        'rights' => nil, # Copyright messages
        'description' => nil, # Description
        'urnid' => "urn:uuid:#{SecureRandom.uuid}", # Identifier
        'stylesheet' => [], # stylesheet file
        'coverfile' => nil, # content file of body of cover page
        'mytoc' => nil, # whether make own table of contents or not
        'params' => '', # specify review2html parameters
        'toclevel' => 3, # level of toc
        'secnolevel' => 2, # level of section #
        'epubversion' => 3,
        'titlepage' => true, # Use title page
        'toc' => nil, # Use table of contents in body
        'colophon' => nil, # Use colophon
        'debug' => nil, # debug flag
        'catalogfile' => 'catalog.yml',
        'language' => 'ja', # XXX default language should be JA??
        'math_format' => nil,
        'htmlext' => 'html',
        'htmlversion' => 5,
        'contentdir' => '.',
        'imagedir' => 'images',
        'image_ext' => %w[png gif jpg jpeg svg ttf woff otf],
        'fontdir' => 'fonts',
        'chapter_file' => 'CHAPS',
        'part_file' => 'PART',
        'reject_file' => 'REJECT',
        'predef_file' => 'PREDEF',
        'postdef_file' => 'POSTDEF',
        'page_metric' => ReVIEW::Book::PageMetric::A5,
        'ext' => '.re',
        'image_types' => %w[.ai .psd .eps .pdf .tif .tiff .png .bmp .jpg .jpeg .gif .svg],
        'bib_file' => 'bib.re',
        'words_file' => nil,
        'colophon_order' => %w[aut csl trl dsr ill cov edt pbl contact prt pht],
        'chapterlink' => true,
        'externallink' => true,
        'join_lines_by_lang' => nil, # experimental. default should be nil
        'table_row_separator' => 'tabs',
        # for Playwright
        'playwright_options' => {
          'playwright_path' => './node_modules/.bin/playwright',
          'selfcrop' => true,
          'pdfcrop_path' => 'pdfcrop',
          'pdftocairo_path' => 'pdftocairo'
        },
        # for IDGXML
        'tableopt' => nil,
        'listinfo' => nil,
        'nolf' => true,
        'chapref' => nil,
        'structuredxml' => nil,
        'pt_to_mm_unit' => 0.3528, # DTP: 1pt = 0.3528mm, JIS: 1pt = 0.3514mm
        # for LaTeX
        'footnotetext' => nil,
        'texcommand' => 'uplatex',
        'texoptions' => '-interaction=nonstopmode -file-line-error -halt-on-error',
        '_texdocumentclass' => ['review-jsbook', ''],
        'texstyle' => ['reviewmacro'],
        'dvicommand' => 'dvipdfmx',
        'dvioptions' => '-d 5 -z 9',
        # for PDFMaker
        'pdfmaker' => {
          'image_scale2width' => true,
          'makeindex' => nil, # Make index page
          'makeindex_command' => 'mendex', # works only when makeindex is true
          'makeindex_options' => '-f -r -I utf8',
          'makeindex_sty' => nil,
          'makeindex_dic' => nil,
          'makeindex_mecab' => true,
          'makeindex_mecab_opts' => '-Oyomi',
          'use_cover_nombre' => true,
          'use_original_image_size' => nil
        },
        'imgmath_options' => {
          'format' => 'png',
          'converter' => 'pdfcrop', # dvipng | pdfcrop
          'pdfcrop_cmd' => 'pdfcrop --hires %i %o',
          'extract_singlepage' => nil,
          'pdfextract_cmd' => 'pdfjam -q --outfile %o %i %p',
          'preamble_file' => nil,
          'fontsize' => 10,
          'lineheight' => 10 * 1.2,
          'pdfcrop_pixelize_cmd' => 'pdftocairo -%t -r 90 -f %p -l %p -singlefile %i %O',
          'dvipng_cmd' => 'dvipng -T tight -z 9 -p %p -l %p -o %o %i'
        },
        'caption_position' => {
          'list' => 'top',
          'image' => 'bottom',
          'table' => 'top',
          'equation' => 'top'
        },
        # for EPUBMaker
        'modified' => Time.now.utc.strftime('%Y-%02m-%02dT%02H:%02M:%02SZ'),
        'isbn' => nil,
        'titlefile' => nil,
        'originaltitlefile' => nil,
        'profile' => nil,
        'direction' => 'ltr',
        'image_maxpixels' => 4_000_000,
        'font_ext' => %w[ttf woff otf],
        'epubmaker' => {
          'flattoc' => nil,
          'flattocindent' => true,
          'ncx_indent' => [],
          'zip_stage1' => 'zip -0Xq',
          'zip_stage2' => 'zip -Xr9Dq',
          'zip_addpath' => nil,
          'hook_beforeprocess' => nil,
          'hook_afterfrontmatter' => nil,
          'hook_afterbody' => nil,
          'hook_afterbackmatter' => nil,
          'hook_aftercopyimage' => nil,
          'hook_prepack' => nil,
          'rename_for_legacy' => nil,
          'verify_target_images' => nil,
          'force_include_images' => [],
          'cover_linear' => nil,
          'back_footnote' => nil
        },
        'textmaker' => {
          'th_bold' => nil
        }
      ]
      conf.maker = nil
      conf
    end

    def self.create(maker: nil, yamlfile: nil, config: nil)
      conf = self.values
      conf.maker = maker

      if yamlfile
        begin
          loader = ReVIEW::YAMLLoader.new
          conf.deep_merge!(loader.load_file(yamlfile))
        rescue StandardError => e
          raise ReVIEW::ConfigError, "yaml error #{e.message}"
        end
      end

      # YAML configs will be overridden by command line options.
      if config
        conf.deep_merge!(config)
      end

      conf.migrate_parameters

      conf
    end

    def migrate_parameters
      # string to array
      %w[subject aut
         a-adp a-ann a-arr a-art a-asn a-aqt a-aft a-aui a-ant a-bkp a-clb a-cmm a-dsr a-edt
         a-ill a-lyr a-mdc a-mus a-nrt a-oth a-pht a-prt a-red a-rev a-spn a-ths a-trc a-trl
         adp ann arr art asn aut aqt aft aui ant bkp clb cmm dsr edt
         ill lyr mdc mus nrt oth pht pbl prt red rev spn ths trc trl
         stylesheet rights].each do |item|
        if self[item] && self[item].is_a?(String)
          self[item] = [self[item]]
        end
      end

      # backward compatibility
      if self['mathml']
        warn '"mathml: true" is obsoleted. Please use "math_format: mathml"'
        self['math_format'] = 'mathml'
      end

      if self['imgmath']
        warn '"imgmath: true" is obsoleted. Please use "math_format: imgmath"'
        self['math_format'] = 'imgmath'
      end
    end

    def [](key)
      maker = self.maker
      if maker && self.key?(maker) && self.fetch(maker) && self.fetch(maker).key?(key)
        return self.fetch(maker).fetch(key, nil)
      end
      if self.key?(key)
        return self.fetch(key)
      end

      nil
    end

    def check_version(version, exception: true)
      unless self.key?('review_version')
        if exception
          raise ReVIEW::ConfigError, 'configuration file has no review_version property.'
        else
          return false
        end
      end

      if self['review_version'].blank?
        return true
      end

      if self['review_version'].to_i != version.to_i ## major version
        if exception
          raise ReVIEW::ConfigError, 'major version of configuration file is different.'
        else
          return false
        end
      elsif self['review_version'].to_f > version.to_f ## minor version
        if exception
          raise ReVIEW::ConfigError, "Re:VIEW version '#{version}' is older than configuration file's version '#{self['review_version']}'."
        else
          return false
        end
      end
      return true
    end

    def name_of(key)
      if self[key].is_a?(Array)
        self[key].join(',') # i18n?
      elsif self[key].is_a?(Hash)
        self[key]['name']
      else
        self[key]
      end
    end

    def names_of(key)
      if self[key].is_a?(Array)
        self[key].map do |a|
          if a.is_a?(Hash)
            a['name']
          else
            a
          end
        end
      elsif self[key].is_a?(Hash)
        [self[key]['name']]
      else
        [self[key]]
      end
    end
  end
end
