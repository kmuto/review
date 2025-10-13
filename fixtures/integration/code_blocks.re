= Code Blocks Test

Testing various code block types.

== Basic Code Lists

Numbered code list:

//list[sample1][Ruby Example]{
def hello_world
  puts "Hello, World!"
  return true
end
//}

Numbered code with line numbers:

//listnum[sample2][Python Example]{
def fibonacci(n):
    if n <= 1:
        return n
    else:
        return fibonacci(n-1) + fibonacci(n-2)

print(fibonacci(10))
//}

== Simple Code Blocks

Simple code block:

//emlist[Simple Ruby]{
puts "Hello"
puts "World"
//}

Simple code with line numbers:

//emlistnum[Numbered Ruby]{
x = 1
y = 2
puts x + y
//}

== Command Examples

Shell commands:

//cmd[Shell Commands]{
ls -la
cd /path/to/directory
git status
git commit -m "Update"
//}

== Source Code

External source file reference:

//source[sample.rb][Sample Ruby File]{
# This would reference an external file
require 'ruby'

class Sample
  def initialize
    @value = 42
  end
end
//}