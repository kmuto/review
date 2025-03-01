# frozen_string_literal: true

require 'test_helper'
require 'review/configure'
require 'review/epubmaker'

class EPUB3MakerTest < Test::Unit::TestCase
  def setup
    config = ReVIEW::Configure.values
    config.merge!(
      'bookname' => 'sample',
      'title' => 'Sample Book',
      'epubversion' => 3,
      'urnid' => 'http://example.jp/',
      'date' => '2011-01-01',
      'language' => 'en',
      'modified' => '2014-12-13T14:15:16Z',
      'titlepage' => nil
    )
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
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" xml:lang="en">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title id="title">Sample Book</dc:title>
    <dc:language id="language">en</dc:language>
    <dc:date id="date">2011-01-01</dc:date>
    <meta property="dcterms:modified">2014-12-13T14:15:16Z</meta>
    <dc:identifier id="BookId">http://example.jp/</dc:identifier>
  </metadata>
  <manifest>
    <item properties="nav" id="sample-toc.html" href="sample-toc.html" media-type="application/xhtml+xml"/>
    <item id="sample" href="sample.html" media-type="application/xhtml+xml"/>
  </manifest>
  <spine page-progression-direction="ltr">
    <itemref idref="sample" linear="no"/>
  </spine>
  <guide>
    <reference type="cover" title="Cover" href="sample.html"/>
    <reference type="toc" title="Table of Contents" href="sample-toc.html"/>
  </guide>
</package>
EOT
    assert_equal expect, output
  end

  def test_stage1_opf_ebpaj
    @producer.config.merge!(
      'opf_prefix' => { 'ebpaj' => 'http://www.ebpaj.jp/' },
      'opf_meta' => { 'ebpaj:guide-version' => '1.1.2' }
    )
    @producer.modify_config
    output = @producer.instance_eval { @epub.opf }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" xml:lang="en" prefix="ebpaj: http://www.ebpaj.jp/">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title id="title">Sample Book</dc:title>
    <dc:language id="language">en</dc:language>
    <dc:date id="date">2011-01-01</dc:date>
    <meta property="dcterms:modified">2014-12-13T14:15:16Z</meta>
    <dc:identifier id="BookId">http://example.jp/</dc:identifier>
    <meta property="ebpaj:guide-version">1.1.2</meta>
  </metadata>
  <manifest>
    <item properties="nav" id="sample-toc.html" href="sample-toc.html" media-type="application/xhtml+xml"/>
    <item id="sample" href="sample.html" media-type="application/xhtml+xml"/>
  </manifest>
  <spine page-progression-direction="ltr">
    <itemref idref="sample" linear="no"/>
  </spine>
  <guide>
    <reference type="cover" title="Cover" href="sample.html"/>
    <reference type="toc" title="Table of Contents" href="sample-toc.html"/>
  </guide>
</package>
EOT
    assert_equal expect, output
  end

  def test_stage1_opf_fileas
    @producer.config.merge!('title' => { 'name' => 'これは書籍です', 'file-as' => 'コレハショセキデス' },
                            'aut' => [{ 'name' => '著者A', 'file-as' => 'チョシャA' }, { 'name' => '著者B', 'file-as' => 'チョシャB' }],
                            'pbl' => [{ 'name' => '出版社', 'file-as' => 'シュッパンシャ' }])
    @producer.modify_config
    output = @producer.instance_eval { @epub.opf }
    expect = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" xml:lang="en">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title id="title">これは書籍です</dc:title>
    <meta refines="#title" property="file-as">コレハショセキデス</meta>
    <dc:language id="language">en</dc:language>
    <dc:date id="date">2011-01-01</dc:date>
    <meta property="dcterms:modified">2014-12-13T14:15:16Z</meta>
    <dc:identifier id="BookId">http://example.jp/</dc:identifier>
    <dc:creator id="aut-0">著者A</dc:creator>
    <meta refines="#aut-0" property="role" scheme="marc:relators">aut</meta>
    <meta refines="#aut-0" property="file-as">チョシャA</meta>
    <dc:creator id="aut-1">著者B</dc:creator>
    <meta refines="#aut-1" property="role" scheme="marc:relators">aut</meta>
    <meta refines="#aut-1" property="file-as">チョシャB</meta>
    <dc:contributor id="pbl-0">出版社</dc:contributor>
    <meta refines="#pbl-0" property="role" scheme="marc:relators">pbl</meta>
    <meta refines="#pbl-0" property="file-as">シュッパンシャ</meta>
    <dc:publisher id="pub-pbl-0">出版社</dc:publisher>
    <meta refines="#pub-pbl-0" property="role" scheme="marc:relators">pbl</meta>
    <meta refines="#pub-pbl-0" property="file-as">シュッパンシャ</meta>
  </metadata>
  <manifest>
    <item properties="nav" id="sample-toc.html" href="sample-toc.html" media-type="application/xhtml+xml"/>
    <item id="sample" href="sample.html" media-type="application/xhtml+xml"/>
  </manifest>
  <spine page-progression-direction="ltr">
    <itemref idref="sample" linear="no"/>
  </spine>
  <guide>
    <reference type="cover" title="Cover" href="sample.html"/>
    <reference type="toc" title="Table of Contents" href="sample-toc.html"/>
  </guide>
</package>
EOT
    assert_equal expect, output
  end

  def test_stage1_ncx
    output = @producer.instance_eval { @epub.ncx([]) }
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
  <nav xmlns:epub="http://www.idpf.org/2007/ops" epub:type="toc" id="toc">
  <h1 class="toc-title">Table of Contents</h1>

<ol class="toc-h1"><li><a href="sample.html">Cover</a></li>
</ol>  </nav>
</body>
</html>
EOT
    assert_equal expect, output

    @producer.config['cover'] = 'mycover.html'
    output = @producer.instance_eval { @epub.ncx([]) }
    assert_equal expect.sub('sample.html', 'mycover.html'), output

    @producer.config['cover'] = nil
    output = @producer.instance_eval { @epub.ncx([]) }
    assert_equal expect.sub(%Q(<li><a href="sample.html">Cover</a></li>\n), ''), output
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
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" xml:lang="en">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title id="title">Sample Book</dc:title>
    <dc:language id="language">en</dc:language>
    <dc:date id="date">2011-01-01</dc:date>
    <meta property="dcterms:modified">2014-12-13T14:15:16Z</meta>
    <dc:identifier id="BookId">http://example.jp/</dc:identifier>
  </metadata>
  <manifest>
    <item properties="nav" id="sample-toc.html" href="sample-toc.html" media-type="application/xhtml+xml"/>
    <item id="sample" href="sample.html" media-type="application/xhtml+xml"/>
    <item id="ch01-html" href="ch01.html" media-type="application/xhtml+xml"/>
  </manifest>
  <spine page-progression-direction="ltr">
    <itemref idref="sample" linear="no"/>
    <itemref idref="ch01-html"/>
  </spine>
  <guide>
    <reference type="cover" title="Cover" href="sample.html"/>
    <reference type="toc" title="Table of Contents" href="sample-toc.html"/>
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
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
  <title>Table of Contents</title>
</head>
<body>
  <nav xmlns:epub="http://www.idpf.org/2007/ops" epub:type="toc" id="toc">
  <h1 class="toc-title">Table of Contents</h1>

<ol class="toc-h1"><li><a href="sample.html">Cover</a></li>
<li><a href="ch01.html">CH01</a></li>
</ol>  </nav>
</body>
</html>
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
    @producer.contents << ReVIEW::EPUBMaker::Content.new(file: 'ch03.html', title: 'CH03', level: 1, properties: ['mathml'])
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
      ReVIEW::EPUBMaker::Content.new(file: 'ch03.html', id: 'ch03-html', media: 'application/xhtml+xml', title: 'CH03', level: 1, properties: ['mathml']),
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
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookId" xml:lang="en">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
    <dc:title id="title">Sample Book</dc:title>
    <dc:language id="language">en</dc:language>
    <dc:date id="date">2011-01-01</dc:date>
    <meta property="dcterms:modified">2014-12-13T14:15:16Z</meta>
    <dc:identifier id="BookId">http://example.jp/</dc:identifier>
  </metadata>
  <manifest>
    <item properties="nav" id="sample-toc.html" href="sample-toc.html" media-type="application/xhtml+xml"/>
    <item id="sample" href="sample.html" media-type="application/xhtml+xml"/>
    <item id="ch01-html" href="ch01.html" media-type="application/xhtml+xml"/>
    <item id="ch02-html" href="ch02.html" media-type="application/xhtml+xml"/>
    <item id="ch03-html" href="ch03.html" media-type="application/xhtml+xml" properties="mathml"/>
    <item id="ch04-html" href="ch04.html" media-type="application/xhtml+xml"/>
    <item id="sample-GIF" href="sample.GIF" media-type="image/gif"/>
    <item id="sample-JPEG" href="sample.JPEG" media-type="image/jpeg"/>
    <item id="sample-SvG" href="sample.SvG" media-type="image/svg+xml"/>
    <item id="sample-css" href="sample.css" media-type="text/css"/>
    <item id="sample-jpg" href="sample.jpg" media-type="image/jpeg"/>
    <item id="sample-png" href="sample.png" media-type="image/png"/>
  </manifest>
  <spine page-progression-direction="ltr">
    <itemref idref="sample" linear="no"/>
    <itemref idref="ch01-html"/>
    <itemref idref="ch02-html"/>
    <itemref idref="ch03-html"/>
    <itemref idref="ch04-html"/>
  </spine>
  <guide>
    <reference type="cover" title="Cover" href="sample.html"/>
    <reference type="toc" title="Table of Contents" href="sample-toc.html"/>
  </guide>
</package>
EOT
    assert_equal expect, output
  end

  def test_stage3_ncx
    stage3
    @producer.config['toclevel'] = 2
    output = @producer.instance_eval { @epub.ncx([]) }
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
  <nav xmlns:epub="http://www.idpf.org/2007/ops" epub:type="toc" id="toc">
  <h1 class="toc-title">Table of Contents</h1>

<ol class="toc-h1"><li><a href="sample.html">Cover</a></li>
<li><a href="ch01.html">CH01&lt;&gt;&amp;&quot;</a></li>
<li><a href="ch02.html">CH02</a>
<ol class="toc-h2"><li><a href="ch02.html#S1">CH02.1</a></li>
<li><a href="ch02.html#S2">CH02.2</a></li>
</ol></li>
<li><a href="ch03.html">CH03</a>
<ol class="toc-h2"><li><a href="ch03.html#S1">CH03.1</a></li>
</ol></li>
<li><a href="ch04.html">CH04</a></li>
</ol>  </nav>
</body>
</html>
EOT
    assert_equal expect, output
  end

  def test_stage3_mytoc
    stage3
    @producer.config['toclevel'] = 2
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

<ul class="toc-h1"><li><a href="sample.html">Cover</a></li>
<li><a href="ch01.html">CH01&lt;&gt;&amp;&quot;</a></li>
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
      'toclevel' => 2,
      'epubmaker' => { 'flattoc' => true, 'flattocindent' => false }
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
<li><a href="sample.html">Cover</a></li>
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
<body epub:type="cover">
<h1 class="cover-title">Sample Book</h1>
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
<body epub:type="cover">
  <div id="cover-image" class="cover-image">
    <img src="sample.png" alt="Sample Book" class="max"/>
  </div>
</body>
</html>
EOT
    assert_equal expect, output
  end

  def test_colophon_default
    @producer.config.merge!('aut' => ['Mr.Smith'],
                            'pbl' => ['BLUEPRINT'])
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
    </table>
  </div>
</body>
</html>
EOT
    assert_equal expect, output
  end

  def test_colophon_pht
    @producer.config.merge!('aut' => ['Mr.Smith'],
                            'pbl' => ['BLUEPRINT'],
                            'pht' => ['Mrs.Smith'])
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

  def test_colophon_history
    @producer.config.merge!('aut' => 'Mr.Smith',
                            'pbl' => 'BLUEPRINT',
                            'pht' => 'Mrs.Smith',
                            'language' => 'ja')
    @producer.modify_config
    history = @producer.instance_eval { @epub.colophon_history }
    expect = <<EOT
    <div class="pubhistory">
      <p>2011年1月1日　発行</p>
    </div>
EOT
    assert_equal expect, history
  end

  def test_colophon_history_2
    @producer.config.merge!('aut' => ['Mr.Smith'],
                            'pbl' => ['BLUEPRINT'],
                            'pht' => ['Mrs.Smith'],
                            'language' => 'ja',
                            'history' => [['2011-08-03 v1.0.0版発行', '2012-02-15 v1.1.0版発行']])
    @producer.modify_config
    history = @producer.instance_eval { @epub.colophon_history }
    expect = <<EOT
    <div class="pubhistory">
      <p>2011年8月3日　v1.0.0版発行</p>
      <p>2012年2月15日　v1.1.0版発行</p>
    </div>
EOT
    assert_equal expect, history
  end

  def test_colophon_history_date
    @producer.config.merge!('aut' => ['Mr.Smith'],
                            'pbl' => ['BLUEPRINT'],
                            'pht' => ['Mrs.Smith'],
                            'language' => 'ja',
                            'history' => [['2011-08-03', '2012-02-15']])
    @producer.modify_config
    history = @producer.instance_eval { @epub.colophon_history }
    expect = <<EOT
    <div class="pubhistory">
      <p>2011年8月3日　初版第1刷　発行</p>
      <p>2012年2月15日　初版第2刷　発行</p>
    </div>
EOT
    assert_equal expect, history
  end

  def test_colophon_history_date2
    @producer.config.merge!('aut' => ['Mr.Smith'],
                            'pbl' => ['BLUEPRINT'],
                            'pht' => ['Mrs.Smith'],
                            'language' => 'ja',
                            'history' => [['2011-08-03', '2012-02-15'],
                                          ['2012-10-01'],
                                          ['2013-03-01']])
    @producer.modify_config
    history = @producer.instance_eval { @epub.colophon_history }
    expect = <<EOT
    <div class="pubhistory">
      <p>2011年8月3日　初版第1刷　発行</p>
      <p>2012年2月15日　初版第2刷　発行</p>
      <p>2012年10月1日　第2版第1刷　発行</p>
      <p>2013年3月1日　第3版第1刷　発行</p>
    </div>
EOT
    assert_equal expect, history
  end

  def test_detect_mathml
    Dir.mktmpdir do |dir|
      epubmaker = ReVIEW::EPUBMaker.new
      path = File.join(dir, 'test.html')
      html = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
  <title>Colophon</title>
</head>
<body>
  <div>
   <p><span class="equation"><math xmlns='http://www.w3.org/1998/Math/MathML' display='inline'><mfrac><mrow><mo stretchy='false'>-</mo><mi>b</mi><mo stretchy='false'>&#xb1;</mo><msqrt><mrow><msup><mi>b</mi><mn>2</mn></msup><mo stretchy='false'>-</mo><mn>4</mn><mi>a</mi><mi>c</mi></mrow></msqrt></mrow><mrow><mn>2</mn><mi>a</mi></mrow></mfrac></math></span></p>
  </div>
</body>
</html>
EOT
      File.write(path, html)
      assert_equal ['mathml'], epubmaker.detect_properties(path)
    end
  end

  def test_detect_mathml_ns
    Dir.mktmpdir do |dir|
      epubmaker = ReVIEW::EPUBMaker.new
      path = File.join(dir, 'test.html')
      html = <<EOT
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
  <title>Colophon</title>
</head>
<body>
  <div>
   <p><span class="equation"><m:math xmlns:m='http://www.w3.org/1998/Math/MathML' display='inline'><m:mfrac><m:mrow><m:mo stretchy='false'>-</m:mo><m:mi>b</m:mi><m:mo stretchy='false'>&#xb1;</m:mo><m:msqrt><m:mrow><m:msup><m:mi>b</m:mi><m:mn>2</m:mn></m:msup><m:mo stretchy='false'>-</m:mo><m:mn>4</m:mn><m:mi>a</m:mi><m:mi>c</m:mi></m:mrow></m:msqrt></m:mrow><m:mrow><m:mn>2</m:mn><m:mi>a</m:mi></m:mrow></m:mfrac></m:math></span></p>
  </div>
</body>
</html>
EOT
      File.write(path, html)
      assert_equal ['mathml'], epubmaker.detect_properties(path)
    end
  end

  def test_image_size
    begin
      require 'image_size'
    rescue LoadError
      $stderr.puts 'skip test_image_size (cannot find image_size.rb)'
      return true
    end
    epubmaker = ReVIEW::EPUBMaker.new
    epubmaker.instance_eval do
      def warn(msg)
        $stderr.puts msg
      end
    end
    _out, err = capture_output do
      epubmaker.check_image_size(assets_dir, 5500, %w[png gif jpg jpeg svg ttf woff otf])
    end

    expected = <<-EOS
large.gif: 250x150 exceeds a limit. suggested value is 95x57
large.jpg: 250x150 exceeds a limit. suggested value is 95x57
large.png: 250x150 exceeds a limit. suggested value is 95x57
large.svg: 250x150 exceeds a limit. suggested value is 95x57
EOS
    assert_equal expected, err
  end

  def test_build_part
    Dir.mktmpdir do |tmpdir|
      book = ReVIEW::Book::Base.new
      book.catalog = ReVIEW::Catalog.new('CHAPS' => %w[ch1.re])
      io1 = StringIO.new("//list[sampletest][a]{\nfoo\n//}\n")
      chap1 = ReVIEW::Book::Chapter.new(book, 1, 'ch1', 'ch1.re', io1)
      part1 = ReVIEW::Book::Part.new(book, 1, [chap1])
      book.parts = [part1]
      epubmaker = ReVIEW::EPUBMaker.new
      epubmaker.instance_eval do
        @config = book.config
        @producer = ReVIEW::EPUBMaker::Producer.new(@config)
      end
      epubmaker.build_part(part1, tmpdir, 'part1.html')

      expected = <<-EOB
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops" xmlns:ops="http://www.idpf.org/2007/ops" xml:lang="ja">
<head>
  <meta charset="UTF-8" />
  <meta name="generator" content="Re:VIEW" />
  <title></title>
</head>
<body>
<div class="part">
<h1 class="part-number">第I部</h1>
</div>
</body>
</html>
      EOB
      assert_equal expected, File.read(File.join(tmpdir, 'part1.html'))
    end
  end
end
