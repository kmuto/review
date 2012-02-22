# -*- coding: utf-8 -*-
module ReVIEW
  class Configure
    def self.values
      { # These parameters can be overridden by YAML file.
        "bookname"=> "example", # it defines epub file name also
        "booktitle" => "ReVIEW EPUBサンプル",
        "title" => "example",
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
        "debug" => nil, # debug flag
      }
    end
  end
end
