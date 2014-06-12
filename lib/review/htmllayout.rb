# Copyright (c) 2009 Narihiro Nakamura <authornari@gmail.com>
require 'erb'

class HTMLLayout
  def initialize(params, template)
    @body = params['body']
    @title = params['title']
    @template = template
  end
  attr_reader :body, :title

  def result
    if File.exist?(@template)
      return ERB.new(IO.read(@template)).result(binding)
    else
      return @src
    end
  end
end
