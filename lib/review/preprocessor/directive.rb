# Copyright (c) 2010-2021 Minero Aoki, Kenshi Muto
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

module ReVIEW
  class Preprocessor
    class Directive
      def initialize(op, args, opts)
        @op = op
        @args = args
        @opts = opts
      end

      attr_reader :op
      attr_reader :args
      attr_reader :opts

      def arg
        @args.first
      end

      def opt
        @opts.first
      end

      def [](key)
        @opts[key]
      end
    end
  end
end
