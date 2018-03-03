require 'test_helper'
require 'epubmaker'
require 'epubmaker/zip_exporter'
require 'fileutils'

class ZipExporterTest < Test::Unit::TestCase
  include EPUBMaker

  def setup
    @tmpdir = Dir.mktmpdir
    @epubdir = "#{@tmpdir}/epubdir"
    FileUtils.mkdir_p("#{@epubdir}/META-INF")
    FileUtils.mkdir_p("#{@epubdir}/OEBPS")
    File.write("#{@epubdir}/mimetype", 'application/epub+zip')

    container_xml = <<-EOB
    <?xml version="1.0" encoding="UTF-8"?>
<container xmlns="urn:oasis:names:tc:opendocument:xmlns:container" version="1.0">
  <rootfiles>
    <rootfile full-path="OEBPS/book.opf" media-type="application/oebps-package+xml" />
  </rootfiles>
</container>
    EOB

    book_opf = <<-EOB
<?xml version="1.0"?>
<package xmlns="http://www.idpf.org/2007/opf" unique-identifier="BookID" version="2.0">
    <metadata xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:opf="http://www.idpf.org/2007/opf">
        <dc:title>sample epub</dc:title>
        <dc:creator opf:role="aut">AUTHOR</dc:creator>
        <dc:language>ja</dc:language>
        <dc:identifier id="BookID" opf:scheme="URL">http://example.com/epub/sample/sample1.epub</dc:identifier>
    </metadata>
    <manifest>
        <item id="ch1.xhtml" href="OEBPS/ch1.xhtml" media-type="application/xhtml+xml"/>
    </manifest>
    <spine toc="ncx">
        <itemref idref="ch1.xhtml"/>
    </spine>
    <guide>
        <reference type="cover" title="Cover Page" href="OEPBS/ch1.xhtml"/>
    </guide>
</package>
    EOB

    ch1_xhtml = <<-EOB
<html>
  <head>
    <title>test</title>
  </head>
  <body>
  <p>hello, world!</p>
  </body>
</html>
    EOB

    File.write("#{@epubdir}/META-INF/container.xml", container_xml)
    File.write("#{@epubdir}/OEBPS/book.opf", book_opf)
    File.write("#{@epubdir}/OEBPS/ch1.xhtml", ch1_xhtml)
  end

  def test_export_zipcmd
    if Gem.win_platform?
      ## skip this test
      return
    end

    config = { 'epubmaker' => {} }
    epubfile = File.join(@tmpdir, 'test.epub')
    exporter = ZipExporter.new(@epubdir, config)
    exporter.export_zip_extcmd(epubfile)
    assert_true(File.exist?(epubfile))

    if defined?(Zip)
      File.open(epubfile) do |f|
        ::Zip::InputStream.open(f) do |fzip|
          ## get first entry
          entry = fzip.get_next_entry
          assert_equal 'mimetype', entry.name
          assert_equal 'application/epub+zip', fzip.read
        end
      end
    end
  end

  def test_export_rubyzip
    return unless defined?(Zip) ## skip test
    config = { 'epubmaker' => {} }
    epubfile = File.join(@tmpdir, 'test.epub')
    exporter = ZipExporter.new(@epubdir, config)
    exporter.export_zip_rubyzip(epubfile)
    assert_true(File.exist?(epubfile))

    File.open(epubfile) do |f|
      ::Zip::InputStream.open(f) do |fzip|
        ## get first entry
        entry = fzip.get_next_entry
        assert_equal 'mimetype', entry.name
        assert_equal 'application/epub+zip', fzip.read
      end
    end
  end

  def teardown
    FileUtils.remove_entry_secure(@tmpdir)
  end
end
