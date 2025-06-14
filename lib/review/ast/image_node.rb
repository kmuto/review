# frozen_string_literal: true

require 'review/ast/node'

module ReVIEW
  module AST
    class ImageNode < Node
      attr_accessor :id, :caption, :metric

      def initialize(location: nil, id: nil, caption: nil, metric: nil, **kwargs)
        super(location: location, id: id, **kwargs)
        @id = id
        @caption = caption
        @metric = metric
      end

      def to_h
        super.merge(
          id: id,
          caption: caption,
          metric: metric
        )
      end

      protected

      def serialize_properties(hash, _options)
        hash[:id] = id
        hash[:caption] = caption
        hash[:metric] = metric
        hash
      end
    end
  end
end
