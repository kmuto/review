# encoding: utf-8

require 'test_helper'
require 'epubmaker'

class EPUBMakerTest < Test::Unit::TestCase
  include EPUBMaker

  def setup
    @producer = Producer.new
    @producer.merge_params({
                            "bookname" => "sample",
                            "title" => "Sample Book",
                            "version" => 2,
                            "urnid" => "http://example.jp/",
                            "date" => "2011-01-01",
                            "language" => "en",
                          })
    @output = StringIO.new
  end

  def test_initialize
    assert Producer.new
  end

  def test_resource_en
    @producer.merge_params({"language" => "en"})
    assert_equal "Table of Contents", @producer.res.v("toctitle")
  end

  def test_resource_ja
    @producer.merge_params({"language" => "ja"})
    assert_equal "目次", @producer.res.v("toctitle")
  end

  def test_mimetype
    @producer.mimetype(@output)
    assert_equal %Q[application/epub+zip], @output.string
  end

  def test_container
    @producer.container(@output)
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
  <rootfiles>
    <rootfile full-path="OEBPS/sample.opf" media-type="application/oebps-package+xml" />
  </rootfiles>
</container>
EOT
    assert_equal expect, @output.string
  end

  def test_stage1_opf
    @producer.opf(@output)
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Sample Book</dc:title>
    <dc:language>en</dc:language>
    <dc:date>2011-01-01</dc:date>
    <dc:identifier id="BookId">http://example.jp/</dc:identifier>
  </metadata>
  <manifest>
    <item id="ncx" href="sample.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="sample" href="sample.html" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="sample" linear="no"/>
  </spine>
  <guide>
    <reference type="cover" title="Cover" href="sample.html"/>
  </guide>
</package>
EOT
    assert_equal expect, @output.string
  end

  def test_stage1_ncx
    @producer.ncx(@output)
   expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
    <meta name="dtb:uid" content="http://example.jp/"/>
  </head>
  <docTitle>
    <text>Sample Book</text>
  </docTitle>
  <docAuthor>
    <text></text>
  </docAuthor>
  <navMap>
    <navPoint id="top" playOrder="1">
      <navLabel>
        <text>Sample Book</text>
      </navLabel>
      <content src="sample.html"/>
    </navPoint>
  </navMap>
</ncx>
EOT
    assert_equal expect, @output.string
  end

  def stage2
    # add one item
    @producer.contents << Content.new({"file" => "ch01.html", "title" => "CH01", "level" => 1})
  end

  def test_stage2_add_l1item
    stage2
    expect = EPUBMaker::Content.new("ch01.html",
                                    "ch01-html",
                                    "application/xhtml+xml",
                                    "CH01",
                                    1)
    assert_equal expect, @producer.contents[0]
  end

  def test_stage2_opf
    stage2
    @producer.opf(@output)
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Sample Book</dc:title>
    <dc:language>en</dc:language>
    <dc:date>2011-01-01</dc:date>
    <dc:identifier id="BookId">http://example.jp/</dc:identifier>
  </metadata>
  <manifest>
    <item id="ncx" href="sample.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="sample" href="sample.html" media-type="application/xhtml+xml"/>
    <item id="ch01-html" href="ch01.html" media-type="application/xhtml+xml"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="sample" linear="no"/>
    <itemref idref="ch01-html"/>
  </spine>
  <guide>
    <reference type="cover" title="Cover" href="sample.html"/>
  </guide>
</package>
EOT
    assert_equal expect, @output.string
  end

  def test_stage2_ncx
    stage2
    @producer.ncx(@output)
   expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
    <meta name="dtb:uid" content="http://example.jp/"/>
  </head>
  <docTitle>
    <text>Sample Book</text>
  </docTitle>
  <docAuthor>
    <text></text>
  </docAuthor>
  <navMap>
    <navPoint id="top" playOrder="1">
      <navLabel>
        <text>Sample Book</text>
      </navLabel>
      <content src="sample.html"/>
    </navPoint>
    <navPoint id="nav-2" playOrder="2">
      <navLabel>
        <text>CH01</text>
      </navLabel>
      <content src="ch01.html"/>
    </navPoint>
  </navMap>
</ncx>
EOT
    assert_equal expect, @output.string
  end

  def stage3
    # add more items
    @producer.contents << Content.new({"file" => "ch01.html", "title" => "CH01<>&\"", "level" => 1})
    @producer.contents << Content.new({"file" => "ch02.html", "title" => "CH02", "level" => 1})
    @producer.contents << Content.new({"file" => "ch02.html#S1", "title" => "CH02.1", "level" => 2})
    @producer.contents << Content.new({"file" => "ch02.html#S1.1", "title" => "CH02.1.1", "level" => 3})
    @producer.contents << Content.new({"file" => "ch02.html#S1.1.1", "title" => "CH02.1.1.1", "level" => 4})
    @producer.contents << Content.new({"file" => "ch02.html#S1.1.1.1", "title" => "CH02.1.1.1.1", "level" => 5})
    @producer.contents << Content.new({"file" => "ch02.html#S1.1.2", "title" => "CH02.1.1.2", "level" => 4})
    @producer.contents << Content.new({"file" => "ch02.html#S2", "title" => "CH02.2", "level" => 2})
    @producer.contents << Content.new({"file" => "ch02.html#S2.1", "title" => "CH02.2.1", "level" => 3})
    @producer.contents << Content.new({"file" => "ch03.html", "title" => "CH03", "level" => 1})
    @producer.contents << Content.new({"file" => "ch03.html#S1", "title" => "CH03.1", "level" => 2})
    @producer.contents << Content.new({"file" => "ch03.html#S1.1", "title" => "CH03.1.1", "level" => 3})
    @producer.contents << Content.new({"file" => "ch04.html", "title" => "CH04", "level" => 1})
    @producer.contents << Content.new({"file" => "sample.png"})
    @producer.contents << Content.new({"file" => "sample.jpg"})
    @producer.contents << Content.new({"file" => "sample.JPEG"})
    @producer.contents << Content.new({"file" => "sample.SvG"})
    @producer.contents << Content.new({"file" => "sample.GIF"})
    @producer.contents << Content.new({"file" => "sample.css"})
  end

  def test_stage3_add_various_items
    stage3
    expect = [
              Content.new("ch01.html", "ch01-html", "application/xhtml+xml", "CH01<>&\"", 1),
              Content.new("ch02.html", "ch02-html", "application/xhtml+xml", "CH02", 1),
              Content.new("ch02.html#S1", "ch02-html#S1","html#s1","CH02.1", 2),
              Content.new("ch02.html#S1.1", "ch02-html#S1-1", "1", "CH02.1.1", 3),
              Content.new("ch02.html#S1.1.1", "ch02-html#S1-1-1","1", "CH02.1.1.1", 4),
              Content.new("ch02.html#S1.1.1.1", "ch02-html#S1-1-1-1", "1","CH02.1.1.1.1", 5),
              Content.new("ch02.html#S1.1.2", "ch02-html#S1-1-2", "2", "CH02.1.1.2", 4),
              Content.new("ch02.html#S2", "ch02-html#S2", "html#s2", "CH02.2", 2),
              Content.new("ch02.html#S2.1", "ch02-html#S2-1", "1", "CH02.2.1", 3),
              Content.new("ch03.html", "ch03-html", "application/xhtml+xml", "CH03", 1),
              Content.new("ch03.html#S1", "ch03-html#S1", "html#s1", "CH03.1", 2),
              Content.new("ch03.html#S1.1", "ch03-html#S1-1", "1", "CH03.1.1", 3),
              Content.new("ch04.html", "ch04-html", "application/xhtml+xml", "CH04", 1),
              Content.new("sample.png", "sample-png", "image/png"),
              Content.new("sample.jpg", "sample-jpg", "image/jpeg"),
              Content.new("sample.JPEG", "sample-JPEG", "image/jpeg"),
              Content.new("sample.SvG", "sample-SvG", "image/svg+xml"),
              Content.new("sample.GIF", "sample-GIF", "image/gif"),
              Content.new("sample.css", "sample-css", "text/css")
             ]

    assert_equal expect, @producer.contents
  end

  def test_stage3_opf
    stage3
    @producer.opf(@output)
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Sample Book</dc:title>
    <dc:language>en</dc:language>
    <dc:date>2011-01-01</dc:date>
    <dc:identifier id="BookId">http://example.jp/</dc:identifier>
  </metadata>
  <manifest>
    <item id="ncx" href="sample.ncx" media-type="application/x-dtbncx+xml"/>
    <item id="sample" href="sample.html" media-type="application/xhtml+xml"/>
    <item id="ch01-html" href="ch01.html" media-type="application/xhtml+xml"/>
    <item id="ch02-html" href="ch02.html" media-type="application/xhtml+xml"/>
    <item id="ch03-html" href="ch03.html" media-type="application/xhtml+xml"/>
    <item id="ch04-html" href="ch04.html" media-type="application/xhtml+xml"/>
    <item id="sample-png" href="sample.png" media-type="image/png"/>
    <item id="sample-jpg" href="sample.jpg" media-type="image/jpeg"/>
    <item id="sample-JPEG" href="sample.JPEG" media-type="image/jpeg"/>
    <item id="sample-SvG" href="sample.SvG" media-type="image/svg+xml"/>
    <item id="sample-GIF" href="sample.GIF" media-type="image/gif"/>
    <item id="sample-css" href="sample.css" media-type="text/css"/>
  </manifest>
  <spine toc="ncx">
    <itemref idref="sample" linear="no"/>
    <itemref idref="ch01-html"/>
    <itemref idref="ch02-html"/>
    <itemref idref="ch03-html"/>
    <itemref idref="ch04-html"/>
  </spine>
  <guide>
    <reference type="cover" title="Cover" href="sample.html"/>
  </guide>
</package>
EOT
    assert_equal expect, @output.string
  end

  def test_stage3_ncx
    stage3
    @producer.ncx(@output)
   expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<ncx xmlns="http://www.daisy.org/z3986/2005/ncx/" version="2005-1">
  <head>
    <meta name="dtb:depth" content="1"/>
    <meta name="dtb:totalPageCount" content="0"/>
    <meta name="dtb:maxPageNumber" content="0"/>
    <meta name="dtb:uid" content="http://example.jp/"/>
  </head>
  <docTitle>
    <text>Sample Book</text>
  </docTitle>
  <docAuthor>
    <text></text>
  </docAuthor>
  <navMap>
    <navPoint id="top" playOrder="1">
      <navLabel>
        <text>Sample Book</text>
      </navLabel>
      <content src="sample.html"/>
    </navPoint>
    <navPoint id="nav-2" playOrder="2">
      <navLabel>
        <text>CH01&lt;&gt;&amp;&quot;</text>
      </navLabel>
      <content src="ch01.html"/>
    </navPoint>
    <navPoint id="nav-3" playOrder="3">
      <navLabel>
        <text>CH02</text>
      </navLabel>
      <content src="ch02.html"/>
    </navPoint>
    <navPoint id="nav-4" playOrder="4">
      <navLabel>
        <text>CH02.1</text>
      </navLabel>
      <content src="ch02.html#S1"/>
    </navPoint>
    <navPoint id="nav-5" playOrder="5">
      <navLabel>
        <text>CH02.1.1</text>
      </navLabel>
      <content src="ch02.html#S1.1"/>
    </navPoint>
    <navPoint id="nav-6" playOrder="6">
      <navLabel>
        <text>CH02.1.1.1</text>
      </navLabel>
      <content src="ch02.html#S1.1.1"/>
    </navPoint>
    <navPoint id="nav-7" playOrder="7">
      <navLabel>
        <text>CH02.1.1.1.1</text>
      </navLabel>
      <content src="ch02.html#S1.1.1.1"/>
    </navPoint>
    <navPoint id="nav-8" playOrder="8">
      <navLabel>
        <text>CH02.1.1.2</text>
      </navLabel>
      <content src="ch02.html#S1.1.2"/>
    </navPoint>
    <navPoint id="nav-9" playOrder="9">
      <navLabel>
        <text>CH02.2</text>
      </navLabel>
      <content src="ch02.html#S2"/>
    </navPoint>
    <navPoint id="nav-10" playOrder="10">
      <navLabel>
        <text>CH02.2.1</text>
      </navLabel>
      <content src="ch02.html#S2.1"/>
    </navPoint>
    <navPoint id="nav-11" playOrder="11">
      <navLabel>
        <text>CH03</text>
      </navLabel>
      <content src="ch03.html"/>
    </navPoint>
    <navPoint id="nav-12" playOrder="12">
      <navLabel>
        <text>CH03.1</text>
      </navLabel>
      <content src="ch03.html#S1"/>
    </navPoint>
    <navPoint id="nav-13" playOrder="13">
      <navLabel>
        <text>CH03.1.1</text>
      </navLabel>
      <content src="ch03.html#S1.1"/>
    </navPoint>
    <navPoint id="nav-14" playOrder="14">
      <navLabel>
        <text>CH04</text>
      </navLabel>
      <content src="ch04.html"/>
    </navPoint>
  </navMap>
</ncx>
EOT
    assert_equal expect, @output.string
  end

  def test_stage3_mytoc
    stage3
    @producer.mytoc(@output)
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
  <meta http-equiv="Content-Style-Type" content="text/css"/>
  <meta name="generator" content="Re:VIEW"/>
  <title>Table of Contents</title>
</head>
<body>
  <h1 class="toc-title">Table of Contents</h1>

<ul class="toc-h1"><li><a href="ch01.html">CH01&lt;&gt;&amp;&quot;</a></li>
<li><a href="ch02.html">CH02</a>
<ul class="toc-h2"><li><a href="ch02.html#S1">CH02.1</a></li>
<li><a href="ch02.html#S2">CH02.2</a></li>
</ul></li>
<li><a href="ch03.html">CH03</a>
<ul class="toc-h2"><li><a href="ch03.html#S1">CH03.1</a></li>
</ul></li>
<li><a href="ch04.html">CH04</a></li>
</ul></body>
</html>
EOT
    assert_equal expect, @output.string
  end

  def test_stage3_flat
    @producer.merge_params({"flattoc" => true, "flattocindent" => false})
    stage3
    @producer.mytoc(@output)
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
  <meta http-equiv="Content-Style-Type" content="text/css"/>
  <meta name="generator" content="Re:VIEW"/>
  <title>Table of Contents</title>
</head>
<body>
  <h1 class="toc-title">Table of Contents</h1>
<ul class="toc-h1">
<li><a href="ch01.html">CH01&lt;&gt;&amp;&quot;</a></li>
<li><a href="ch02.html">CH02</a></li>
<li><a href="ch02.html#S1">CH02.1</a></li>
<li><a href="ch02.html#S2">CH02.2</a></li>
<li><a href="ch03.html">CH03</a></li>
<li><a href="ch03.html#S1">CH03.1</a></li>
<li><a href="ch04.html">CH04</a></li>
</ul>
</body>
</html>
EOT
    assert_equal expect, @output.string
  end

  def test_stage3_cover
    stage3
    @producer.cover(@output)
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
  <meta http-equiv="Content-Style-Type" content="text/css"/>
  <meta name="generator" content="Re:VIEW"/>
  <title>Sample Book</title>
</head>
<body>
<h1 class="cover-title">Sample Book</h1>
</body>
</html>
EOT
    assert_equal expect, @output.string
  end

  def test_stage3_cover_with_image
    stage3
    @producer.params["coverimage"] = "sample.png"
    @producer.cover(@output)
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
  <meta http-equiv="Content-Style-Type" content="text/css"/>
  <meta name="generator" content="Re:VIEW"/>
  <title>Sample Book</title>
</head>
<body>
  <div id="cover-image" class="cover-image">
    <img src="sample.png" alt="Sample Book" class="max"/>
  </div>
</body>
</html>
EOT
    assert_equal expect, @output.string
  end

  def test_colophon_default
    @producer.params["aut"] = ["Mr.Smith"]
    @producer.params["prt"] = ["BLUEPRINT"]
    @producer.colophon(@output)
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
  <meta http-equiv="Content-Style-Type" content="text/css"/>
  <meta name="generator" content="Re:VIEW"/>
  <title>Colophon</title>
</head>
<body>
  <div class="colophon">
    <p class="title">Sample Book</p>
    <div class="pubhistory">
      <p>2011年1月1日　発行</p>
    </div>
    <table class="colophon">
      <tr><th>Author</th><td>Mr.Smith</td></tr>
      <tr><th>Publisher</th><td>BLUEPRINT</td></tr>
    </table>
  </div>
</body>
</html>
EOT
    assert_equal expect, @output.string
  end

  def test_colophon_pht
    @producer.params["aut"] = ["Mr.Smith"]
    @producer.params["prt"] = ["BLUEPRINT"]
    @producer.params["pht"] = ["Mrs.Smith"]
    @producer.colophon(@output)
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta http-equiv="Content-Type" content="text/html;charset=UTF-8"/>
  <meta http-equiv="Content-Style-Type" content="text/css"/>
  <meta name="generator" content="Re:VIEW"/>
  <title>Colophon</title>
</head>
<body>
  <div class="colophon">
    <p class="title">Sample Book</p>
    <div class="pubhistory">
      <p>2011年1月1日　発行</p>
    </div>
    <table class="colophon">
      <tr><th>Author</th><td>Mr.Smith</td></tr>
      <tr><th>Publisher</th><td>BLUEPRINT</td></tr>
      <tr><th>Director of Photography</th><td>Mrs.Smith</td></tr>
    </table>
  </div>
</body>
</html>
EOT
    assert_equal expect, @output.string
  end

#  def test_duplicate_id
#    stage3
#    assert_raise(Error) do
#      @producer.contents << Content.new({"file" => "ch02.html#S1", "title" => "CH02.1", "level" => 2})
#    end
#  end

end
