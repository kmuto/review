require 'test_helper'
require 'review/preprocessor'
require 'stringio'
require 'book_test_helper'

class PreprocessorTest < Test::Unit::TestCase
  include ReVIEW
  include BookTestHelper

  def test_mapfile
    preproc = ReVIEW::Preprocessor.new({})

    ch01_re = <<-'REFILE'
= test1

//list[hello.rb.1][hello.re]{
#@mapfile(hello.rb)
#@end
//}
REFILE

    hello_rb = <<-'RBFILE'
#!/usr/bin/env ruby

class Hello
  def hello(name)
    print "hello, #{name}!\n"
  end
end

if __FILE__ == $0
  Hello.new.hello("world")
end
RBFILE

    expected = <<-'EXPECTED'
= test1

//list[hello.rb.1][hello.re]{
#@mapfile(hello.rb)
#!/usr/bin/env ruby

class Hello
  def hello(name)
    print "hello, #{name}!\n"
  end
end

if __FILE__ == $0
  Hello.new.hello("world")
end
#@end
//}
EXPECTED
    converted = mktmpbookdir('catalog.yml' => "CHAPS:\n - ch01.re\n",
                             'ch01.re' => ch01_re,
                             'hello.rb' => hello_rb) do |_dir, _book, _files|
      preproc.process('ch01.re')
    end
    assert_equal expected, converted
  end

  def test_mapfile_tabwidth_is_4
    param = { 'tabwidth' => 4 }
    preproc = ReVIEW::Preprocessor.new(param)

    ch01 = <<-'REFILE'
//emlist[test1][inc.txt]{
#@mapfile(inc.txt)
#@end
//}
REFILE

    inc_txt = <<-INC_TXT
test.
	test2.

	test3.

	  test4.

			test5.
INC_TXT

    expected = <<-'EXPECTED'
//emlist[test1][inc.txt]{
#@mapfile(inc.txt)
test.
    test2.

    test3.

      test4.

            test5.
#@end
//}
EXPECTED
    converted = nil
    mktmpbookdir('catalog.yml' => "CHAPS:\n - ch01.re\n",
                 'inc.txt' => inc_txt,
                 'ch01.re' => ch01) do |_dir, _book, _files|
      converted = preproc.process('ch01.re')
    end
    assert_equal expected, converted
  end

  def test_maprange
    preproc = ReVIEW::Preprocessor.new({})

    ch01_re = <<-'REFILE'
//list[range.rb][range.rb(抜粋)]{
#@maprange(range.rb,sample)
#@end
//}
REFILE

    range_rb = <<-'RBFILE'
#!/usr/bin/env ruby

class Hello
#@range_begin(sample)
  def hello(name)
    print "hello, #{name}!\n"
  end
#@range_end(sample)
end

if __FILE__ == $0
  Hello.new.hello("world")
end
RBFILE

    expected = <<-'EXPECTED'
//list[range.rb][range.rb(抜粋)]{
#@maprange(range.rb,sample)
  def hello(name)
    print "hello, #{name}!\n"
  end
#@end
//}
EXPECTED
    converted = mktmpbookdir('catalog.yml' => "CHAPS:\n - ch01.re\n",
                             'ch01.re' => ch01_re,
                             'range.rb' => range_rb) do |_dir, _book, _files|
      preproc.process('ch01.re')
    end
    assert_equal expected, converted
  end

  def test_at_at_maprange
    preproc = ReVIEW::Preprocessor.new({})

    ch01_re = <<-'REFILE'
//list[range.c][range.c(抜粋)]{
#@maprange(range.c,sample)
#@end
//}
REFILE

    range_c = <<-'CFILE'
#include <stdio.h>

/* #@@range_begin(sample)  */
void
put_hello(char *name)
{
  printf("hello, %s!\n", name);
}
/* #@@range_end(sample) */

int main()
{
  put_hello("world");
}
CFILE

    expected = <<-'EXPECTED'
//list[range.c][range.c(抜粋)]{
#@maprange(range.c,sample)
void
put_hello(char *name)
{
  printf("hello, %s!\n", name);
}
#@end
//}
EXPECTED
    converted = mktmpbookdir('catalog.yml' => "CHAPS:\n - ch01.re\n",
                             'ch01.re' => ch01_re,
                             'range.c' => range_c) do |_dir, _book, _files|
      preproc.process('ch01.re')
    end
    assert_equal expected, converted
  end
end
