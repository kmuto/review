require 'test_helper'
require 'rexml/document'
require 'rexml/streamlistener'
require 'review/epubmaker'

class ReVIEWHeaderListenerTest < Test::Unit::TestCase
  def setup
    @epubmaker = ReVIEW::EPUBMaker.new
  end

  def teardown
  end

  def test_epubmaker_parse_headlines
    # original Re:VIEW source:
    #
    # = first chapter
    # == first section
    # === first @<embed>{<img src="images/icon1.jpg" alt="subsection" />}
    # == second section
    # ==={dummy1} dummy subsection
    # == third section
    # ==[notoc] notoc section
    # ==[notoc]{dummy2} notoc section
    # ==[nodisp] nodisp section
    # ==[nodisp]{dummy3} nodisp section
    # ==[nonum] nonum section
    # ==[nonum]{dummy4} nonum section
    Dir.mktmpdir do |_dir|
      path = File.join(assets_dir, 'header_listener.html')
      headlines = @epubmaker.parse_headlines(path)

      expected = [{ 'id' => 'h1', 'level' => 1, 'notoc' => nil, 'title' => '第1章　first chapter' },
                  { 'id' => 'h1-1', 'level' => 2, 'notoc' => nil, 'title' => '1.1　first section' },
                  { 'id' => 'h1-1-1', 'level' => 3, 'notoc' => nil, 'title' => 'first subsection' },
                  { 'id' => 'h1-2', 'level' => 2, 'notoc' => nil, 'title' => '1.2　second section' },
                  { 'id' => 'h1-2-1', 'level' => 3, 'notoc' => nil, 'title' => 'dummy subsection' },
                  { 'id' => 'h1-3', 'level' => 2, 'notoc' => nil, 'title' => '1.3　third section' },
                  { 'id' => 'ch01_nonum1', 'level' => 2, 'notoc' => 'true', 'title' => 'notoc section' },
                  { 'id' => 'dummy2', 'level' => 2, 'notoc' => 'true', 'title' => 'notoc section' },
                  { 'id' => 'ch01_nonum3', 'level' => 2, 'notoc' => nil, 'title' => 'nodisp section' },
                  { 'id' => 'dummy3', 'level' => 2, 'notoc' => nil, 'title' => 'nodisp section' },
                  { 'id' => 'ch01_nonum5', 'level' => 2, 'notoc' => nil, 'title' => 'nonum section' },
                  { 'id' => 'dummy4', 'level' => 2, 'notoc' => nil, 'title' => 'nonum section' }]

      assert_equal expected, headlines
    end
  end
end
