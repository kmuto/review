# frozen_string_literal: true

# Test helper class for parsing captions
class CaptionParserHelper
  def self.parse(caption, location: nil, inline_processor: nil)
    new(location: location, inline_processor: inline_processor).parse(caption)
  end

  def initialize(location: nil, inline_processor: nil)
    @location = location
    @inline_processor = inline_processor
  end

  def parse(caption)
    return nil if caption.nil? || caption == ''
    return caption if caption.is_a?(ReVIEW::AST::CaptionNode)

    parse_string(caption)
  end

  private

  def parse_string(caption)
    require 'review/ast/caption_node'
    require 'review/ast/text_node'

    caption_node = ReVIEW::AST::CaptionNode.new(location: @location)
    if @inline_processor && caption.include?('@<')
      @inline_processor.parse_inline_elements(caption, caption_node)
    else
      caption_node.add_child(ReVIEW::AST::TextNode.new(location: @location, content: caption))
    end
    caption_node
  end
end
