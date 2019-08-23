#
# Copyright (c) 2012-2019 Masanori Kado, Masayoshi Takahashi, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#
require 'securerandom'

module ReVIEW
  class Configure < Hash
    attr_accessor :maker

    def self.values
      conf = Configure[
        # These parameters can be overridden by YAML file.
        'bookname' => 'example', # it defines epub file name also
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
        'urnid' => "urn:uid:#{SecureRandom.uuid}", # Identifier
        'stylesheet' => 'stylesheet.css', # stylesheet file
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
        'mathml' => nil, # for HTML
        'imgmath' => nil, # for HTML
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
        'colophon_order' => %w[aut csl trl dsr ill cov edt pbl contact prt],
        'externallink' => true,
        # for IDGXML
        'tableopt' => nil,
        'listinfo' => nil,
        'nolf' => true,
        'chapref' => nil,
        'structuredxml' => nil,
        'pt_to_mm_unit' => 0.3528, # DTP: 1pt = 0.3528mm, JIS: 1pt = 0.3514mm
        # for LaTeX
        'image_scale2width' => true,
        'footnotetext' => nil,
        'texcommand' => 'uplatex',
        'texoptions' => '-interaction=nonstopmode -file-line-error -halt-on-error',
        '_texdocumentclass' => ['review-jsbook', ''],
        'dvicommand' => 'dvipdfmx',
        'dvioptions' => '-d 5 -z 9',
        # for PDFMaker
        'pdfmaker' => {
          'makeindex' => nil, # Make index page
          'makeindex_command' => 'mendex', # works only when makeindex is true
          'makeindex_options' => '-f -r -I utf8',
          'makeindex_sty' => nil,
          'makeindex_dic' => nil,
          'makeindex_mecab' => true,
          'makeindex_mecab_opts' => '-Oyomi'
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
        }
      ]
      conf.maker = nil
      conf
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
