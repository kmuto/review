# -*- coding: utf-8 -*-
module ReVIEW
  class Configure < Hash

    attr_accessor :maker

    def self.values
      conf = Configure[
        # These parameters can be overridden by YAML file.
        "bookname"=> "example", # it defines epub file name also
        "booktitle" => "Re:VIEW Sample Book",
        "title" => nil,
        "aut" => nil, # author
        "prt" => nil, # printer(publisher)
        "asn" => nil, # associated name
        "ant" => nil, # bibliographic antecedent
        "clb" => nil, # Collaborator
        "edt" => nil, # Editor
        "dsr" => nil, # Designer
        "ill" => nil, # Illustrator
        "pht" => nil, # Photographer
        "trl" => nil, # Translator
        "date" => nil, # publishing date
        "rights" => nil, # Copyright messages
        "description" => nil, # Description
        "urnid" => nil, # Identifier (nil makes random uuid)
        "stylesheet" => "stylesheet.css", # stylesheet file
        "coverfile" => nil, # content file of body of cover page
        "mytoc" => nil, # whether make own table of contents or not
        "params" => "", # specify review2html parameters
        "toclevel" => 3, # level of toc
        "secnolevel" => 2, # level of section #
        "epubversion" => 3,
        "titlepage" => true, # Use title page
        "toc" => nil, # Use table of contents in body
        "colophon" => nil, # Use colophon
        "debug" => nil, # debug flag
        "catalogfile" => 'catalog.yml',
        "language" => 'ja', # XXX default language should be JA??
        "mathml" => nil, # for HTML
        "htmlext" => "html",
        "htmlversion" => 5,

        "chapter_file" => 'CHAPS',
        "part_file" => 'PART',
        "reject_file" => 'REJECT',
        "predef_file" => 'PREDEF',
        "postdef_file" => 'POSTDEF',
        "page_metric" => ReVIEW::Book::PageMetric.a5,
        "ext" => '.re',
        "image_dir" => 'images',
        "image_types" => %w( .ai .psd .eps .pdf .tif .tiff .png .bmp .jpg .jpeg .gif .svg ),
        "bib_file" => "bib.re",
        "colophon_order" => %w(aut csl trl dsr ill cov edt pbl contact prt),
        "tableopt" => nil,      # for IDGXML
        "listinfo" => nil,      # for IDGXML
        "nolf" => true,         # for IDGXML
        "chapref" => nil,       # for IDGXML
        "structuredxml" => nil, # for IDGXML
        "footnotetext" => nil,  # for LaTeX
      ]
      conf.maker = nil
      conf
    end

    def [](key)
      maker = self.maker
      if maker && self.key?(maker) && self.fetch(maker).key?(key)
        return self.fetch(maker).fetch(key, nil)
      end
      if self.key?(key)
        return self.fetch(key)
      end
    end

    def name_of(key)
      if self[key].kind_of?(Array)
        self[key].join(",") # i18n?
      elsif self[key].kind_of?(Hash)
        self[key]["name"]
      else
        self[key]
      end
    end

    def names_of(key)
      if self[key].kind_of?(Array)
        self[key].map do |a|
          if a.kind_of?(Hash)
            a["name"]
          else
            a
          end
        end
      elsif self[key].kind_of?(Hash)
        [self[key]["name"]]
      else
        [self[key]]
      end
    end
  end
end
