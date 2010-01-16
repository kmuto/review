#
# $Id: exception.rb 3881 2008-02-09 14:44:17Z aamine $
#
# Copyright (c) 2002-2007 Minero Aoki
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

end
