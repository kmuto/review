require 'test_helper'
require 'review/htmlbuilder'
require 'review/img_graph'

class ImgGraphTest < Test::Unit::TestCase
  def setup
    @config = ReVIEW::Configure.values
    @tmpdir = Dir.mktmpdir

    @playwright_path = install_playwright
    @config['imagedir'] = @tmpdir
    @config['playwright_options']['playwright_path'] = @playwright_path

    @img_graph = ReVIEW::ImgGraph.new(@config, 'latex')
  end

  def teardown
    @img_graph.cleanup_graphimg
    FileUtils.rm_rf(@tmpdir)
  end

  def install_playwright
    begin
      `npm -v`
    rescue StandardError
      return nil
    end

    json = <<-EOB
{
  "name": "imggraph-test",
  "dependencies": {
    "playwright": "^1.32.2"
  }
}
EOB
    File.write(File.join(@tmpdir, 'package.json'), json)
    Dir.chdir(@tmpdir) do
      system('npm install')
    end

    File.join(@tmpdir, 'node_modules', '.bin', 'playwright')
  end

  def prepare_mermaid_data
    content = <<-EOB
graph TD
A[Client] --> B[Load Balancer]
B --> C[Server1]
B --> D[Server2]
EOB
    @img_graph.defer_mermaid_image(content, 'testid1')
  end

  def test_make_mermaid_pdf
    unless @playwright_path
      $stderr.puts 'skip test_make_mermaid_pdf (cannot find playwright)'
      return true
    end

    prepare_mermaid_data
    @img_graph.make_mermaid_images

    assert File.size(File.join(@tmpdir, 'latex', 'testid1.pdf')) > 0
  end

  def test_make_mermaid_svg
    unless @playwright_path
      $stderr.puts 'skip test_make_mermaid_svg (cannot find playwright)'
      return true
    end

    begin
      `pdftocairo -v`
    rescue StandardError
      $stderr.puts 'skip test_make_mermaid_svg (cannot find pdftocairo)'
      return true
    end

    @img_graph = ReVIEW::ImgGraph.new(@config, 'html')
    prepare_mermaid_data
    @img_graph.make_mermaid_images

    assert File.size(File.join(@tmpdir, 'html', 'testid1.svg')) > 0
  end
end
