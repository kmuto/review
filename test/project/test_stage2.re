= Stage 2 Test Chapter

This is a basic paragraph that contains some text. It should be processed via AST in Stage 2, while maintaining compatibility with traditional processing.

== Section with Multiple Paragraphs

Here's the first paragraph of this section. It contains multiple sentences. Each sentence adds to the overall meaning.

And here's a second paragraph. Notice how paragraphs are separated by blank lines. This is standard Re:VIEW formatting.

This third paragraph includes @<b>{bold text} and @<i>{italic text} with inline elements. It also has @<code>{inline code} examples.

=== Subsection with Complex Content

A paragraph before a list.

//list[example][Example Code]{
def hello(name)
  puts "Hello, #{name}!"
end
//}

A paragraph after the code block. This paragraph references @<list>{example} from above.

//table[data][Sample Data]{
Name	Age	City
------------
Alice	25	Tokyo
Bob	30	Osaka
//}

Another paragraph after the table. Tables like @<table>{data} are useful for structured information.

==== Deep Section

Final paragraph with a footnote@<fn>{note1} reference.

//footnote[note1][This is a sample footnote that provides additional context.]