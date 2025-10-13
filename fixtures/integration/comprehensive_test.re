= Comprehensive AST Test

This chapter provides comprehensive testing for AST features including cross-references.

== Cross References

This section demonstrates various types of references:

 * Reference to @<chap>{basic_elements}
 * Reference to @<chapref>{lists}
 * Reference to @<list>{sample-code}
 * Reference to @<table>{sample-table}
 * Reference to @<img>{sample-image}

== Sample Elements

=== Code Block with Reference

//list[sample-code][Sample Code Block]{
def hello_world
  puts "Hello, World!"
end
//}

See @<list>{sample-code} for a simple Ruby example.

=== Table with Reference

//table[sample-table][Sample Table]{
Name	Age	City
Alice	25	Tokyo
Bob	30	Osaka
//}

The data in @<table>{sample-table} shows sample user information.

=== Image with Reference

//image[sample-image][Sample Image Caption]{
//}

@<img>{sample-image} demonstrates image referencing.

== Links to Other Chapters

For basic elements, see @<chap>{basic_elements}.
For list examples, refer to @<chap>{lists}.
For table and image examples, check @<chap>{tables_images}.

== Advanced Features

=== Nested Lists with References

 * Main item referencing @<chap>{basic_elements}
  * Sub-item with @<code>{inline code}
  * Another sub-item
 * Second main item
  * Referencing @<table>{sample-table}

=== Mixed Content

This paragraph contains @<b>{bold text}, @<i>{italic text}, 
@<code>{inline code}, and a reference to @<chap>{complex_structure}.

 1. First step: read @<chap>{basic_elements}
 2. Second step: understand @<chap>{lists}  
 3. Third step: review @<chap>{tables_images}

=== Definition List with References

 : AST
    Abstract Syntax Tree - see @<chap>{basic_elements} for details
 : Re:VIEW
    Document authoring system - examples in @<chap>{simple_test}
 : Cross-reference
    Link to other parts - demonstrated throughout this chapter