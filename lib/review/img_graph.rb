#
# Copyright (c) 2023 Kenshi Muto
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
#
require 'review/loggable'

module ReVIEW
  class ImgGraph
    include Loggable

    def initialize(config, target_name, path_name: '_review_graph')
      @config = config
      @target_name = target_name
      @logger = ReVIEW.logger
      @graph_dir = File.join(@config['imagedir'], target_name, path_name)
      @graph_maps = {}
    end

    attr_reader :graph_maps

    def cleanup_graphimg
      FileUtils.rm_rf(@graph_dir)
    end

    def graph_ext
      if %w[html markdown rst].include?(@target_name)
        'svg'
      else
        'pdf'
      end
    end

    def defer_mermaid_image(str, key)
      @graph_maps[key] = { type: 'mermaid', content: str }
      File.join('.', @config['imagedir'], @target_name, "#{key}.#{graph_ext}")
    end

    def mermaid_html(content)
      <<-EOB
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><script type="module">import mermaid from 'https://cdn.jsdelivr.net/npm/mermaid@10/dist/mermaid.esm.min.mjs'; mermaid.initialize({ startOnLoad: true });</script></head>
<body><div><pre class="mermaid">#{content}</pre></div></body></html>
EOB
    end

    def make_mermaid_images
      mermaid_graph_maps = @graph_maps.select { |_k, v| v[:type] == 'mermaid' }
      return if mermaid_graph_maps.empty?

      FileUtils.mkdir_p(File.join(@graph_dir, 'mermaid'))
      mermaid_graph_maps.each_pair do |key, val|
        File.write(File.join(@graph_dir, 'mermaid', "#{key}.html"), mermaid_html(val[:content]))
      end
      @logger.info 'calling Playwright'

      begin
        require 'playwrightrunner'
        PlaywrightRunner.mermaids_to_images(
          { playwright_path: @config['playwright_options']['playwright_path'],
            selfcrop: @config['playwright_options']['selfcrop'],
            pdfcrop_path: @config['playwright_options']['pdfcrop_path'],
            pdftocairo_path: @config['playwright_options']['pdftocairo_path'] },
          src: File.join(@graph_dir, 'mermaid'),
          dest: File.join(@config['imagedir'], @target_name),
          type: graph_ext
        )
      rescue SystemCallError => e
        raise ApplicationError, "converting mermaid failed: #{e}"
      rescue LoadError
        raise ApplicationError, 'could not handle Mermaid of //graph in this builder.'
      end
      FileUtils.rm_rf(File.join(@graph_dir, 'mermaid'))
    end
  end
end
