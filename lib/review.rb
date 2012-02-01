if defined?(Encoding) && Encoding.respond_to?("default_external")
  Encoding.default_external = "UTF-8"
end
require 'review/i18n'
require 'review/exception'
require 'review/compiler'
require 'review/htmlbuilder'
