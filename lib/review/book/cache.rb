#
# Copyright (c) 2014-2024 Minero Aoki, Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of LGPL, see the file "COPYING".
#
module ReVIEW
  module Book
    class Cache
      def initialize
        @store = {}
      end

      def reset
        @store.clear
      end

      # key should be Symbol, not String
      def fetch(key, &block)
        raise ArgumentError, 'Key should be Symbol' unless key.is_a?(Symbol)

        if cached?(key)
          read(key)
        else
          exec_block_and_save(key, &block)
        end
      end

      def cached?(key)
        @store.key?(key)
      end

      private

      def read(key)
        @store[key]
      end

      def write(key, value)
        @store[key] = value
      end

      def exec_block_and_save(key)
        result = yield(key)

        write(key, result)

        result
      end
    end
  end
end
