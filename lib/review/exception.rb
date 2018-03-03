#
# Copyright (c) 2007-2017 Minero Aoki, Kenshi Muto
#               2002-2007 Minero Aoki
#
# This program is free software.
# You can distribute or modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

module ReVIEW
  class Error < ::StandardError; end
  class ApplicationError < Error; end
  class ConfigError < ApplicationError; end
  class CompileError < ApplicationError; end
  class SyntaxError < CompileError; end
  class FileNotFound < ApplicationError; end
  class KeyError < CompileError; end
end
