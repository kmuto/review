# -*- coding: utf-8 -*-
module ReVIEW
  class Configure < Hash
    def self.values
      Configure[
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
        "posthook" => nil, # command path of post hook
        "epubversion" => 2,
        "titlepage" => true, # Use title page
        "toc" => nil, # Use table of contents in body
        "colophon" => nil, # Use colophon
        "debug" => nil, # debug flag
        "catalogfile" => 'catalog.yml',

        "chapter_file" => 'CHAPS',
        "part_file"    => 'PART',
        "reject_file"  => 'REJECT',
        "predef_file"  => 'PREDEF',
        "postdef_file" => 'POSTDEF',
        "page_metric"  => ReVIEW::Book::PageMetric.a5,
        "ext"          => '.re',
        "image_dir"    => 'images',
        "image_types"  => %w( .ai .psd .eps .pdf .tif .tiff .png .bmp .jpg .jpeg .gif .svg ),
        "bib_file"     => "bib.re",
        "colophon_order" => %w(aut csl trl dsr ill cov edt pbl contact prt),
      ]
    end
  end
end
