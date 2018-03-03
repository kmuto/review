require 'test_helper'
require 'book_test_helper'
require 'review/compiler'
require 'review/htmlbuilder'

class ReviewExtTest < Test::Unit::TestCase
  include BookTestHelper

  def test_builder_init_on_review_ext
    review_ext = <<-EOB
module ReVIEW
  class HTMLBuilder
    attr_reader :builder_init_test
    def builder_init
      @builder_init_test = "test"
    end
  end
end
    EOB

    ReVIEW::Book::Base.clear_rubyenv ## to load review-ext.rb
    mktmpbookdir('CHAPS' => "ch01.re\n",
                 'ch01.re' => "= test\n\ntest.\n",
                 'review-ext.rb' => review_ext) do |_dir, _book, _files|
      builder = ReVIEW::HTMLBuilder.new(false)
      ReVIEW::Compiler.new(builder)
      assert_equal 'test', builder.builder_init_test
    end
  end
end
