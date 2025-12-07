# frozen_string_literal: true

# Copyright (c) 2025 Kenshi Muto, Masayoshi Takahashi
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.

require 'optparse'
require 'review/version'

module ReVIEW
  module AST
    module Command
      module Vivliostyle
        module CLI
          # ParsedOptions holds the result of command line argument parsing
          ParsedOptions = Struct.new(:cmd_config, :yamlfile, :buildonly, keyword_init: true)

          # Parser handles command line argument parsing for VivliostyleMaker
          class Parser
            def self.parse(args)
              new.parse(args)
            end

            def parse(args)
              cmd_config = {}
              buildonly = nil

              opts = OptionParser.new
              opts.banner = 'Usage: review-ast-vivliostylemaker [options] configfile'
              opts.version = ReVIEW::VERSION

              opts.on('--help', 'Prints this message and quit.') do
                puts opts.help
                exit 0
              end

              opts.on('--[no-]debug', 'Keep temporary files.') do |debug|
                cmd_config['debug'] = debug
              end

              opts.on('--ignore-errors', 'Ignore compile errors.') do
                cmd_config['ignore-errors'] = true
              end

              opts.on('-y', '--only file1,file2,...', 'Build only specified files.') do |v|
                buildonly = v.split(/\s*,\s*/).map { |m| m.strip.sub(/\.re\Z/, '') }
              end

              opts.parse!(args)

              if args.size != 1
                puts opts.help
                exit 0
              end

              ParsedOptions.new(
                cmd_config: cmd_config,
                yamlfile: args[0],
                buildonly: buildonly
              )
            end
          end
        end
      end
    end
  end
end
