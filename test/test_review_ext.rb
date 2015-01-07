# encoding: utf-8

require 'test_helper'
require 'book_test_helper'
require 'review/compiler'
require 'review/book'
require 'review/htmlbuilder'

class ReviewExtTest < Test::Unit::TestCase
  include BookTestHelper

  def test_builder_init_on_review_ext
    review_ext = <<-EOB
module ReVIEW
  class HTMLBuilder
    def builder_init
      @builder_init_test = "test"
    end
  end
end
    EOB

    mktmpbookdir('CHAPS' => "ch01.re\n",
                 "ch01.re" => "= test\n\ntest.\n",
                 "review-ext.rb" => review_ext) do |dir, book, files|
      builder = ReVIEW::HTMLBuilder.new(false)
      c = ReVIEW::Compiler.new(builder)
      assert_equal "test", builder.instance_eval{@builder_init_test}
    end
  end
end
