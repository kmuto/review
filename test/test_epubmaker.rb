# frozen_string_literal: true

require 'test_helper'
require 'review/epubmaker'

class EPUBMakerTest < Test::Unit::TestCase
  def setup
    config = ReVIEW::Configure.values
    config.merge!(
      'bookname' => 'sample',
      'booktitle' => 'Sample Book',
      'title' => 'Sample Book',
      'epubversion' => 2,
      'urnid' => 'http://example.jp/',
      'date' => '2011-01-01',
      'language' => 'en',
      'titlepage' => nil
    )
    @log_io = StringIO.new
    ReVIEW.logger = ReVIEW::Logger.new(@log_io)
    @producer = ReVIEW::EPUBMaker::Producer.new(config)
  end

  def test_initialize
    assert ReVIEW::EPUBMaker::Producer.new(ReVIEW::Configure.values)
  end

  def test_resource_en
    @producer.config['language'] = 'en'
    @producer.modify_config
    assert_equal 'Table of Contents', ReVIEW::I18n.t('toctitle')
  end

  def test_resource_ja
    @producer.config['language'] = 'ja'
    @producer.modify_config
    assert_equal '目次', ReVIEW::I18n.t('toctitle')
  end

  def test_mimetype
    output = @producer.instance_eval { @epub.mimetype }
    assert_equal 'application/epub+zip', output
  end

  def test_container
    output = @producer.instance_eval { @epub.container }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
  <rootfiles>
    <rootfile full-path="OEBPS/sample.opf" media-type="application/oebps-package+xml" />
  </rootfiles>
</container>
EOT
    assert_equal expect, output
  end

  def test_stage1_opf
    output = @producer.instance_eval { @epub.opf }
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
    assert_equal expect, output
  end

  def test_stage1_opf_escape
    @producer.config['title'] = 'Sample<>Book'
    @producer.modify_config
    output = @producer.instance_eval { @epub.opf }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<package version="2.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title>Sample&lt;&gt;Book</dc:title>
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
    assert_equal expect, output
  end

  def test_stage1_ncx
    output = @producer.instance_eval { @epub.ncx([]) }
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
    assert_equal expect, output
  end

  def test_stage1_ncx_escape
    @producer.config['title'] = 'Sample<>Book'
    @producer.modify_config
    output = @producer.instance_eval { @epub.ncx([]) }
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
    <text>Sample&lt;&gt;Book</text>
  </docTitle>
  <docAuthor>
    <text></text>
  </docAuthor>
  <navMap>
    <navPoint id="top" playOrder="1">
      <navLabel>
        <text>Sample&lt;&gt;Book</text>
      </navLabel>
      <content src="sample.html"/>
    </navPoint>
  </navMap>
</ncx>
EOT
    assert_equal expect, output
  end

  def stage2
    # add one item
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch01.html', title: 'CH01', level: 1)
  end

  def test_stage2_add_l1item
    stage2
    expect = ReVIEW::EPUBMaker::Content.new(file: 'ch01.html',
                                            id: 'ch01-html',
                                            media: 'application/xhtml+xml',
                                            title: 'CH01',
                                            level: 1)
    assert_equal expect, @producer.contents[0]
  end

  def test_stage2_opf
    stage2
    output = @producer.instance_eval { @epub.opf }
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
    assert_equal expect, output
  end

  def test_stage2_ncx
    stage2
    output = @producer.instance_eval { @epub.ncx([]) }
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
    assert_equal expect, output
  end

  def stage3
    # add more items
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch01.html', title: %Q(CH01<>&"), level: 1)
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch02.html', title: 'CH02', level: 1)
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch02.html#S1', title: 'CH02.1', level: 2)
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch02.html#S1.1', title: 'CH02.1.1', level: 3)
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch02.html#S1.1.1', title: 'CH02.1.1.1', level: 4)
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch02.html#S1.1.1.1', title: 'CH02.1.1.1.1', level: 5)
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch02.html#S1.1.2', title: 'CH02.1.1.2', level: 4)
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch02.html#S2', title: 'CH02.2', level: 2)
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch02.html#S2.1', title: 'CH02.2.1', level: 3)
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch03.html', title: 'CH03', level: 1)
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch03.html#S1', title: 'CH03.1', level: 2)
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch03.html#S1.1', title: 'CH03.1.1', level: 3)
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch04.html', title: 'CH04', level: 1)
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'sample.png')
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'sample.jpg')
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'sample.JPEG')
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'sample.SvG')
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'sample.GIF')
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'sample.css')
  end

  def test_stage3_add_various_items
    stage3
    expect = [
      ReVIEW::EPUBMaker::Content.new(file: 'ch01.html', id: 'ch01-html', media: 'application/xhtml+xml', title: %Q(CH01<>&"), level: 1),
      ReVIEW::EPUBMaker::Content.new(file: 'ch02.html', id: 'ch02-html', media: 'application/xhtml+xml', title: 'CH02', level: 1),
      ReVIEW::EPUBMaker::Content.new(file: 'ch02.html#S1', id: 'ch02-html#S1', media: 'html#s1', title: 'CH02.1', level: 2),
      ReVIEW::EPUBMaker::Content.new(file: 'ch02.html#S1.1', id: 'ch02-html#S1-1', media: '1', title: 'CH02.1.1', level: 3),
      ReVIEW::EPUBMaker::Content.new(file: 'ch02.html#S1.1.1', id: 'ch02-html#S1-1-1', media: '1', title: 'CH02.1.1.1', level: 4),
      ReVIEW::EPUBMaker::Content.new(file: 'ch02.html#S1.1.1.1', id: 'ch02-html#S1-1-1-1', media: '1', title: 'CH02.1.1.1.1', level: 5),
      ReVIEW::EPUBMaker::Content.new(file: 'ch02.html#S1.1.2', id: 'ch02-html#S1-1-2', media: '2', title: 'CH02.1.1.2', level: 4),
      ReVIEW::EPUBMaker::Content.new(file: 'ch02.html#S2', id: 'ch02-html#S2', media: 'html#s2', title: 'CH02.2', level: 2),
      ReVIEW::EPUBMaker::Content.new(file: 'ch02.html#S2.1', id: 'ch02-html#S2-1', media: '1', title: 'CH02.2.1', level: 3),
      ReVIEW::EPUBMaker::Content.new(file: 'ch03.html', id: 'ch03-html', media: 'application/xhtml+xml', title: 'CH03', level: 1),
      ReVIEW::EPUBMaker::Content.new(file: 'ch03.html#S1', id: 'ch03-html#S1', media: 'html#s1', title: 'CH03.1', level: 2),
      ReVIEW::EPUBMaker::Content.new(file: 'ch03.html#S1.1', id: 'ch03-html#S1-1', media: '1', title: 'CH03.1.1', level: 3),
      ReVIEW::EPUBMaker::Content.new(file: 'ch04.html', id: 'ch04-html', media: 'application/xhtml+xml', title: 'CH04', level: 1),
      ReVIEW::EPUBMaker::Content.new(file: 'sample.png', id: 'sample-png', media: 'image/png'),
      ReVIEW::EPUBMaker::Content.new(file: 'sample.jpg', id: 'sample-jpg', media: 'image/jpeg'),
      ReVIEW::EPUBMaker::Content.new(file: 'sample.JPEG', id: 'sample-JPEG', media: 'image/jpeg'),
      ReVIEW::EPUBMaker::Content.new(file: 'sample.SvG', id: 'sample-SvG', media: 'image/svg+xml'),
      ReVIEW::EPUBMaker::Content.new(file: 'sample.GIF', id: 'sample-GIF', media: 'image/gif'),
      ReVIEW::EPUBMaker::Content.new(file: 'sample.css', id: 'sample-css', media: 'text/css')
    ]

    assert_equal expect, @producer.contents
  end

  def test_stage3_opf
    stage3
    output = @producer.instance_eval { @epub.opf }
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
    <item id="sample-GIF" href="sample.GIF" media-type="image/gif"/>
    <item id="sample-JPEG" href="sample.JPEG" media-type="image/jpeg"/>
    <item id="sample-SvG" href="sample.SvG" media-type="image/svg+xml"/>
    <item id="sample-css" href="sample.css" media-type="text/css"/>
    <item id="sample-jpg" href="sample.jpg" media-type="image/jpeg"/>
    <item id="sample-png" href="sample.png" media-type="image/png"/>
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
    assert_equal expect, output
  end

  def test_stage3_ncx
    stage3
    output = @producer.instance_eval { @epub.ncx([]) }
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
    assert_equal expect, output
  end

  def test_stage3_mytoc
    stage3
    @producer.config['toclevel'] = 2
    @producer.modify_config
    output = @producer.instance_eval { @epub.mytoc }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
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
    assert_equal expect, output
  end

  def test_stage3_flat
    @producer.config.deep_merge!(
      'epubmaker' => { 'flattoc' => true, 'flattocindent' => false },
      'toclevel' => 2
    )
    @producer.modify_config
    stage3
    output = @producer.instance_eval { @epub.mytoc }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
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
    assert_equal expect, output
  end

  def test_stage3_cover
    stage3
    output = @producer.instance_eval { @epub.cover }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
  <title>Sample Book</title>
</head>
<body>
<h1 class="cover-title">Sample Book</h1>
</body>
</html>
EOT
    assert_equal expect, output
  end

  def test_stage3_cover_escape
    stage3
    @producer.config['title'] = 'Sample<>Book'
    @producer.modify_config
    output = @producer.instance_eval { @epub.cover }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
  <title>Sample&lt;&gt;Book</title>
</head>
<body>
<h1 class="cover-title">Sample&lt;&gt;Book</h1>
</body>
</html>
EOT
    assert_equal expect, output
  end

  def test_stage3_cover_with_image
    stage3
    @producer.config['coverimage'] = 'sample.png'
    @producer.modify_config
    output = @producer.instance_eval { @epub.cover }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
  <title>Sample Book</title>
</head>
<body>
  <div id="cover-image" class="cover-image">
    <img src="sample.png" alt="Sample Book" class="max"/>
  </div>
</body>
</html>
EOT
    assert_equal expect, output
  end

  def test_stage3_cover_with_image_escape
    stage3
    @producer.config.merge!(
      'title' => 'Sample<>Book',
      'coverimage' => 'sample.png'
    )
    @producer.modify_config
    output = @producer.instance_eval { @epub.cover }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
  <title>Sample&lt;&gt;Book</title>
</head>
<body>
  <div id="cover-image" class="cover-image">
    <img src="sample.png" alt="Sample&lt;&gt;Book" class="max"/>
  </div>
</body>
</html>
EOT
    assert_equal expect, output
  end

  def test_colophon_default
    @producer.config.merge!(
      'aut' => ['Mr.Smith'],
      'pbl' => ['BLUEPRINT'],
      'isbn' => '9784797372274'
    )
    @producer.modify_config
    output = @producer.instance_eval { @epub.colophon }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
  <title>Colophon</title>
</head>
<body>
  <div class="colophon">
    <p class="title">Sample Book</p>
    <div class="pubhistory">
      <p>published by Jan.  1, 2011</p>
    </div>
    <table class="colophon">
      <tr><th>Author</th><td>Mr.Smith</td></tr>
      <tr><th>Publisher</th><td>BLUEPRINT</td></tr>
      <tr><th>ISBN</th><td>978-4-79737-227-4</td></tr>
    </table>
  </div>
</body>
</html>
EOT
    assert_equal expect, output
  end

  def test_colophon_default_escape_and_multiple
    @producer.config.merge!(
      'title' => '<&Sample Book>',
      'subtitle' => 'Sample<>Subtitle',
      'aut' => ['Mr.Smith', 'Mr.&Anderson'],
      'pbl' => ['BLUEPRINT', 'COPY<>EDIT'],
      'isbn' => '9784797372274',
      'rights' => ['COPYRIGHT 2016 <>', '& REVIEW']
    )
    @producer.modify_config
    output = @producer.instance_eval { @epub.colophon }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
  <title>Colophon</title>
</head>
<body>
  <div class="colophon">
    <p class="title">&lt;&amp;Sample Book&gt;<br /><span class="subtitle">Sample&lt;&gt;Subtitle</span></p>
    <div class="pubhistory">
      <p>published by Jan.  1, 2011</p>
    </div>
    <table class="colophon">
      <tr><th>Author</th><td>Mr.Smith, Mr.&amp;Anderson</td></tr>
      <tr><th>Publisher</th><td>BLUEPRINT, COPY&lt;&gt;EDIT</td></tr>
      <tr><th>ISBN</th><td>978-4-79737-227-4</td></tr>
    </table>
    <p class="copyright">COPYRIGHT 2016 &lt;&gt;<br />&amp; REVIEW</p>
  </div>
</body>
</html>
EOT
    assert_equal expect, output
  end

  def test_colophon_history
    @producer.config.merge!(
      'aut' => ['Mr.Smith'],
      'pbl' => ['BLUEPRINT'],
      'pht' => ['Mrs.Smith'],
      'language' => 'ja',
      'history' =>
      [['2011-08-03',
        '2012-02-15'],
       ['2012-10-01'],
       ['2013-03-01']]
    )
    @producer.modify_config
    epub = @producer.instance_eval { @epub }
    result = epub.colophon_history
    expect = <<-EOT
    <div class="pubhistory">
      <p>2011年8月3日　初版第1刷　発行</p>
      <p>2012年2月15日　初版第2刷　発行</p>
      <p>2012年10月1日　第2版第1刷　発行</p>
      <p>2013年3月1日　第3版第1刷　発行</p>
    </div>
    EOT
    assert_equal expect, result
  end

  def test_colophon_history_freeformat
    @producer.config.merge!(
      'aut' => ['Mr.Smith'],
      'pbl' => ['BLUEPRINT'],
      'pht' => ['Mrs.Smith'],
      'language' => 'ja',
      'history' =>
      [['2011年8月3日 ver 1.1.0発行'],
       ['2011年10月12日 ver 1.2.0発行'],
       ['2012年1月31日 ver 1.2.1発行']]
    )
    @producer.modify_config

    epub = @producer.instance_eval { @epub }
    result = epub.colophon_history
    expect = <<-EOT
    <div class="pubhistory">
      <p>2011年8月3日 ver 1.1.0発行</p>
      <p>2011年10月12日 ver 1.2.0発行</p>
      <p>2012年1月31日 ver 1.2.1発行</p>
    </div>
    EOT
    assert_equal expect, result
  end

  def test_colophon_pht
    @producer.config.merge!(
      'aut' => ['Mr.Smith'],
      'pbl' => ['BLUEPRINT'],
      'pht' => ['Mrs.Smith']
    )
    @producer.modify_config
    output = @producer.instance_eval { @epub.colophon }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
  <title>Colophon</title>
</head>
<body>
  <div class="colophon">
    <p class="title">Sample Book</p>
    <div class="pubhistory">
      <p>published by Jan.  1, 2011</p>
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
    assert_equal expect, output
  end

  def test_isbn13
    @producer.config['isbn'] = '9784797372274'
    @producer.modify_config
    isbn = @producer.instance_eval { @epub.isbn_hyphen }
    assert_equal '978-4-79737-227-4', isbn
  end

  def test_isbn10
    @producer.config['isbn'] = '4797372273'
    @producer.modify_config
    isbn = @producer.instance_eval { @epub.isbn_hyphen }
    assert_equal '4-79737-227-3', isbn
  end

  def test_isbn_nil
    @producer.config['isbn'] = nil
    @producer.modify_config
    isbn = @producer.instance_eval { @epub.isbn_hyphen }
    assert_equal nil, isbn
  end

  def test_title
    @producer.config.merge!(
      'aut' => ['Mr.Smith'],
      'pbl' => ['BLUEPRINT']
    )
    @producer.modify_config
    output = @producer.instance_eval { @epub.titlepage }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
  <title>Sample Book</title>
</head>
<body>
<div class="titlepage">
<h1 class="tp-title">Sample Book</h1>
<h2 class="tp-author">Mr.Smith</h2>
<h3 class="tp-publisher">BLUEPRINT</h3>
</div>
</body>
</html>
EOT
    assert_equal expect, output
  end

  def test_title_single_value_param
    @producer.config.merge!(
      'aut' => 'Mr.Smith',
      'pbl' => 'BLUEPRINT'
    )
    @producer.modify_config
    output = @producer.instance_eval { @epub.titlepage }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
  <title>Sample Book</title>
</head>
<body>
<div class="titlepage">
<h1 class="tp-title">Sample Book</h1>
<h2 class="tp-author">Mr.Smith</h2>
<h3 class="tp-publisher">BLUEPRINT</h3>
</div>
</body>
</html>
EOT
    assert_equal expect, output
  end

  def test_epub_unsafe_id
    content = ReVIEW::EPUBMaker::Content.new(file: 'sample.png')
    assert_equal 'sample-png', content.id
    content = ReVIEW::EPUBMaker::Content.new(file: 'sample-&()-=+@:,漢字.png')
    assert_equal 'sample-_25_26_25_28_25_29-_25_3D_25_2B_25_40_25_3A_25_2C_25_E6_25_BC_25_A2_25_E5_25_AD_25_97-png', content.id
  end

  def epubmaker_instance
    begin
      Dir.mktmpdir do |tmpdir|
        epubmaker = ReVIEW::EPUBMaker.new
        epubmaker.instance_eval do
          @config = ReVIEW::Configure.create(maker: 'epubmaker')
          @config['titlepage'] = nil
          @producer = ReVIEW::EPUBMaker::Producer.new(@config)

          @htmltoc = ReVIEW::HTMLToc.new(tmpdir)

          def config
            @config
          end

          def producer
            @producer
          end

          def error(s)
            raise ApplicationError, s
          end
        end

        File.write(File.join(tmpdir, 'exist.css'), 'body {}')
        File.write(File.join(tmpdir, 'exist.html'), '<html></html>')

        Dir.mkdir(File.join(tmpdir, 'subdir'))
        File.write(File.join(tmpdir, 'subdir', 'exist.html'), '<html></html>')

        Dir.mkdir(File.join(tmpdir, 'test'))
        File.write(File.join(tmpdir, 'test', 'ch01.html'), '<html><img src="images/ch01.png" /></html>')
        File.write(File.join(tmpdir, 'test', 'style.css'), 'div { background-image: url("images/bg.jpg")}')

        Dir.chdir(tmpdir) do
          yield(epubmaker, File.join(tmpdir, 'test'))
        end
      end
    rescue Errno::EACCES, Errno::ENOTEMPTY
      # Windows fails unlink when file is opened
    end
  end

  def test_copy_static_file
    epubmaker_instance do |epubmaker, tmpdir|
      epubmaker.config['stylesheet'] = ['exist.css']
      assert_nothing_raised { epubmaker.copy_stylesheet(tmpdir) }

      epubmaker.config['stylesheet'] = ['nothing.css']
      assert_raise(SystemExit) { epubmaker.copy_stylesheet(tmpdir) }
      assert_equal "ERROR --: stylesheet: nothing.css is not found.\n", @log_io.string
    end

    epubmaker_instance do |epubmaker, tmpdir|
      epubmaker.config['titlepage'] = true
      epubmaker.config['titlefile'] = 'exist.html'
      assert_nothing_raised { epubmaker.copy_frontmatter(tmpdir) }

      epubmaker.config['titlefile'] = 'subdir/exist.html'
      assert_nothing_raised { epubmaker.copy_frontmatter(tmpdir) }

      epubmaker.config['titlefile'] = 'nothing.html'
      @log_io.rewind
      @log_io.truncate(0)
      assert_raise(SystemExit) { epubmaker.copy_frontmatter(tmpdir) }
      assert_equal "ERROR --: titlefile: nothing.html is not found.\n", @log_io.string
    end

    # XXX: only `cover' is allowed to have invalid file name.
    %w[originaltitlefile creditfile].each do |name|
      epubmaker_instance do |epubmaker, tmpdir|
        epubmaker.config[name] = 'exist.html'
        assert_nothing_raised { epubmaker.copy_frontmatter(tmpdir) }

        epubmaker.config[name] = 'subdir/exist.html'
        assert_nothing_raised { epubmaker.copy_frontmatter(tmpdir) }

        epubmaker.config[name] = 'nothing.html'
        @log_io.rewind
        @log_io.truncate(0)
        assert_raise(SystemExit) { epubmaker.copy_frontmatter(tmpdir) }
        assert_equal "ERROR --: #{name}: nothing.html is not found.\n", @log_io.string
      end
    end

    %w[profile advfile colophon backcover].each do |name|
      epubmaker_instance do |epubmaker, tmpdir|
        epubmaker.config[name] = 'exist.html'
        assert_nothing_raised { epubmaker.copy_backmatter(tmpdir) }

        epubmaker.config[name] = 'subdir/exist.html'
        assert_nothing_raised { epubmaker.copy_backmatter(tmpdir) }

        epubmaker.config[name] = 'nothing.html'
        @log_io.rewind
        @log_io.truncate(0)
        assert_raise(SystemExit) { epubmaker.copy_backmatter(tmpdir) }
        assert_equal "ERROR --: #{name}: nothing.html is not found.\n", @log_io.string
      end
    end
  end

  def test_verify_target_images
    epubmaker_instance do |epubmaker, tmpdir|
      epubmaker.config['epubmaker']['verify_target_images'] = true
      epubmaker.config['coverimage'] = 'cover.png'

      epubmaker.producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch01.html', title: 'CH01', level: 1)
      epubmaker.producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'style.css')
      epubmaker.verify_target_images(tmpdir)

      expect = %w[images/bg.jpg images/ch01.png images/cover.png]
      assert_equal expect, epubmaker.config['epubmaker']['force_include_images']
      assert_equal true, true
    end
  end
end
