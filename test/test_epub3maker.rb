require 'test_helper'
require 'epubmaker'
require 'review/epubmaker'

class EPUB3MakerTest < Test::Unit::TestCase
  include EPUBMaker

  def setup
    @producer = Producer.new
    @producer.merge_config(
      'bookname' => 'sample',
      'title' => 'Sample Book',
      'epubversion' => 3,
      'urnid' => 'http://example.jp/',
      'date' => '2011-01-01',
      'language' => 'en',
      'modified' => '2014-12-13T14:15:16Z',
      'titlepage' => nil
    )
    @output = StringIO.new
  end

  def test_initialize
    assert Producer.new
  end

  def test_resource_en
    @producer.merge_config('language' => 'en')
    assert_equal 'Table of Contents', @producer.res.v('toctitle')
  end

  def test_resource_ja
    @producer.merge_config('language' => 'ja')
    assert_equal '目次', @producer.res.v('toctitle')
  end

  def test_mimetype
    @producer.mimetype(@output)
    assert_equal 'application/epub+zip', @output.string
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
    assert_equal expect, @output.string
  end

  def test_stage1_opf_ebpaj
    @producer.merge_config(
      'opf_prefix' => { 'ebpaj' => 'http://www.ebpaj.jp/' },
      'opf_meta' => { 'ebpaj:guide-version' => '1.1.2' }
    )
    @producer.opf(@output)
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
    assert_equal expect, @output.string
  end

  def test_stage1_opf_fileas
    @producer.config['title'] = { 'name' => 'これは書籍です', 'file-as' => 'コレハショセキデス' }
    @producer.config['aut'] = [{ 'name' => '著者A', 'file-as' => 'チョシャA' }, { 'name' => '著者B', 'file-as' => 'チョシャB' }]
    @producer.config['pbl'] = [{ 'name' => '出版社', 'file-as' => 'シュッパンシャ' }]
    @producer.opf(@output)
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
    assert_equal expect, @output.string
  end

  def test_stage1_ncx
    @producer.ncx(@output)
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

<ol class="toc-h1"></ol>  </nav>
</body>
</html>
EOT
    assert_equal expect, @output.string
  end

  def stage2
    # add one item
    @producer.contents << Content.new({ 'file' => 'ch01.html', 'title' => 'CH01', 'level' => 1 })
  end

  def test_stage2_add_l1item
    stage2
    expect = EPUBMaker::Content.new('ch01.html',
                                    'ch01-html',
                                    'application/xhtml+xml',
                                    'CH01',
                                    1)
    assert_equal expect, @producer.contents[0]
  end

  def test_stage2_opf
    stage2
    @producer.opf(@output)
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
    assert_equal expect, @output.string
  end

  def test_stage2_ncx
    stage2
    @producer.ncx(@output)
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

<ol class="toc-h1"><li><a href="ch01.html">CH01</a></li>
</ol>  </nav>
</body>
</html>
EOT
    assert_equal expect, @output.string
  end

  def stage3
    # add more items
    @producer.contents << Content.new({ 'file' => 'ch01.html', 'title' => %Q(CH01<>&"), 'level' => 1 })
    @producer.contents << Content.new({ 'file' => 'ch02.html', 'title' => 'CH02', 'level' => 1 })
    @producer.contents << Content.new({ 'file' => 'ch02.html#S1', 'title' => 'CH02.1', 'level' => 2 })
    @producer.contents << Content.new({ 'file' => 'ch02.html#S1.1', 'title' => 'CH02.1.1', 'level' => 3 })
    @producer.contents << Content.new({ 'file' => 'ch02.html#S1.1.1', 'title' => 'CH02.1.1.1', 'level' => 4 })
    @producer.contents << Content.new({ 'file' => 'ch02.html#S1.1.1.1', 'title' => 'CH02.1.1.1.1', 'level' => 5 })
    @producer.contents << Content.new({ 'file' => 'ch02.html#S1.1.2', 'title' => 'CH02.1.1.2', 'level' => 4 })
    @producer.contents << Content.new({ 'file' => 'ch02.html#S2', 'title' => 'CH02.2', 'level' => 2 })
    @producer.contents << Content.new({ 'file' => 'ch02.html#S2.1', 'title' => 'CH02.2.1', 'level' => 3 })
    @producer.contents << Content.new({ 'file' => 'ch03.html', 'title' => 'CH03', 'level' => 1, 'properties' => ['mathml'] })
    @producer.contents << Content.new({ 'file' => 'ch03.html#S1', 'title' => 'CH03.1', 'level' => 2 })
    @producer.contents << Content.new({ 'file' => 'ch03.html#S1.1', 'title' => 'CH03.1.1', 'level' => 3 })
    @producer.contents << Content.new({ 'file' => 'ch04.html', 'title' => 'CH04', 'level' => 1 })
    @producer.contents << Content.new({ 'file' => 'sample.png' })
    @producer.contents << Content.new({ 'file' => 'sample.jpg' })
    @producer.contents << Content.new({ 'file' => 'sample.JPEG' })
    @producer.contents << Content.new({ 'file' => 'sample.SvG' })
    @producer.contents << Content.new({ 'file' => 'sample.GIF' })
    @producer.contents << Content.new({ 'file' => 'sample.css' })
  end

  def test_stage3_add_various_items
    stage3
    expect = [
      Content.new('ch01.html', 'ch01-html', 'application/xhtml+xml', %Q(CH01<>&"), 1),
      Content.new('ch02.html', 'ch02-html', 'application/xhtml+xml', 'CH02', 1),
      Content.new('ch02.html#S1', 'ch02-html#S1', 'html#s1', 'CH02.1', 2),
      Content.new('ch02.html#S1.1', 'ch02-html#S1-1', '1', 'CH02.1.1', 3),
      Content.new('ch02.html#S1.1.1', 'ch02-html#S1-1-1', '1', 'CH02.1.1.1', 4),
      Content.new('ch02.html#S1.1.1.1', 'ch02-html#S1-1-1-1', '1', 'CH02.1.1.1.1', 5),
      Content.new('ch02.html#S1.1.2', 'ch02-html#S1-1-2', '2', 'CH02.1.1.2', 4),
      Content.new('ch02.html#S2', 'ch02-html#S2', 'html#s2', 'CH02.2', 2),
      Content.new('ch02.html#S2.1', 'ch02-html#S2-1', '1', 'CH02.2.1', 3),
      Content.new('ch03.html', 'ch03-html', 'application/xhtml+xml', 'CH03', 1, nil, ['mathml']),
      Content.new('ch03.html#S1', 'ch03-html#S1', 'html#s1', 'CH03.1', 2),
      Content.new('ch03.html#S1.1', 'ch03-html#S1-1', '1', 'CH03.1.1', 3),
      Content.new('ch04.html', 'ch04-html', 'application/xhtml+xml', 'CH04', 1),
      Content.new('sample.png', 'sample-png', 'image/png'),
      Content.new('sample.jpg', 'sample-jpg', 'image/jpeg'),
      Content.new('sample.JPEG', 'sample-JPEG', 'image/jpeg'),
      Content.new('sample.SvG', 'sample-SvG', 'image/svg+xml'),
      Content.new('sample.GIF', 'sample-GIF', 'image/gif'),
      Content.new('sample.css', 'sample-css', 'text/css')
    ]

    assert_equal expect, @producer.contents
  end

  def test_stage3_opf
    stage3
    @producer.opf(@output)
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
    <item id="sample-png" href="sample.png" media-type="image/png"/>
    <item id="sample-jpg" href="sample.jpg" media-type="image/jpeg"/>
    <item id="sample-JPEG" href="sample.JPEG" media-type="image/jpeg"/>
    <item id="sample-SvG" href="sample.SvG" media-type="image/svg+xml"/>
    <item id="sample-GIF" href="sample.GIF" media-type="image/gif"/>
    <item id="sample-css" href="sample.css" media-type="text/css"/>
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
    assert_equal expect, @output.string
  end

  def test_stage3_ncx
    stage3
    @producer.ncx(@output)
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

<ol class="toc-h1"><li><a href="ch01.html">CH01&lt;&gt;&amp;&quot;</a></li>
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
    assert_equal expect, @output.string
  end

  def test_stage3_mytoc
    stage3
    @producer.mytoc(@output)
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
    assert_equal expect, @output.string
  end

  def test_stage3_flat
    @producer.merge_config('epubmaker' => { 'flattoc' => true, 'flattocindent' => false })
    stage3
    @producer.mytoc(@output)
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
    assert_equal expect, @output.string
  end

  def test_stage3_cover
    stage3
    @producer.cover(@output)
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
    assert_equal expect, @output.string
  end

  def test_stage3_cover_with_image
    stage3
    @producer.config['coverimage'] = 'sample.png'
    @producer.cover(@output)
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
    assert_equal expect, @output.string
  end

  def test_colophon_default
    @producer.config['aut'] = ['Mr.Smith']
    @producer.config['pbl'] = ['BLUEPRINT']
    @producer.colophon(@output)
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
    assert_equal expect, @output.string
  end

  def test_colophon_pht
    @producer.config['aut'] = ['Mr.Smith']
    @producer.config['pbl'] = ['BLUEPRINT']
    @producer.config['pht'] = ['Mrs.Smith']
    @producer.colophon(@output)
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
    assert_equal expect, @output.string
  end

  def test_colophon_history
    @producer.config['aut'] = ['Mr.Smith']
    @producer.config['pbl'] = ['BLUEPRINT']
    @producer.config['pht'] = ['Mrs.Smith']
    @producer.merge_config('language' => 'ja')
    history = @producer.instance_eval { @epub.colophon_history }
    expect = <<EOT
    <div class="pubhistory">
      <p>2011年1月1日　発行</p>
    </div>
EOT
    assert_equal expect, history
  end

  def test_colophon_history_2
    @producer.config['aut'] = ['Mr.Smith']
    @producer.config['pbl'] = ['BLUEPRINT']
    @producer.config['pht'] = ['Mrs.Smith']
    @producer.merge_config(
      'language' => 'ja',
      'history' => [['2011-08-03 v1.0.0版発行', '2012-02-15 v1.1.0版発行']]
    )
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
    @producer.config['aut'] = ['Mr.Smith']
    @producer.config['pbl'] = ['BLUEPRINT']
    @producer.config['pht'] = ['Mrs.Smith']
    @producer.merge_config(
      'language' => 'ja',
      'history' => [['2011-08-03', '2012-02-15']]
    )
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
    @producer.config['aut'] = ['Mr.Smith']
    @producer.config['pbl'] = ['BLUEPRINT']
    @producer.config['pht'] = ['Mrs.Smith']
    @producer.merge_config(
      'language' => 'ja',
      'history' => [['2011-08-03', '2012-02-15'],
                    ['2012-10-01'],
                    ['2013-03-01']]
    )
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
      File.open(path, 'w') { |f| f.write(html) }
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
      File.open(path, 'w') { |f| f.write(html) }
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
large.gif: 250x150 exceeds a limit. suggeted value is 95x57
large.jpg: 250x150 exceeds a limit. suggeted value is 95x57
large.png: 250x150 exceeds a limit. suggeted value is 95x57
large.svg: 250x150 exceeds a limit. suggeted value is 95x57
EOS
    assert_equal expected, err
  end
end
