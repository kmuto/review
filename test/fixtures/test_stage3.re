= Stage 3 Test - Lists

This chapter tests various list types that should be processed via AST in Stage 3.

== Unordered Lists (ulist)

Here are some basic unordered lists:

 * First item
 * Second item
 * Third item with @<b>{bold text}

Nested unordered list:

 * Top level item
 ** Nested item 1
 ** Nested item 2
 *** Deeply nested item
 ** Back to second level
 * Another top level item

== Ordered Lists (olist)

Basic ordered list:

 1. First step
 2. Second step with @<code>{inline code}
 3. Third step

Nested ordered list:

 1. Main step one
 11. Sub-step 1.1
 12. Sub-step 1.2
 2. Main step two
 21. Sub-step 2.1
 211. Deep sub-step 2.1.1
 22. Sub-step 2.2

== Definition Lists (dlist)

Basic definition list:

 : Term 1
    Definition for term 1
 : Term 2
    Definition for term 2 with @<i>{italic text}
 : Term 3
    Multi-line definition
    can span multiple lines

Complex definition list:

 : API
    Application Programming Interface
 : HTML
    HyperText Markup Language - used for creating @<b>{web pages}
 : CSS
    Cascading Style Sheets
    Used for styling HTML documents
    Supports various selectors and properties

== Mixed Content

A paragraph before the list.

 * List item one
 * List item two

A paragraph between lists.

 1. Ordered item one
 2. Ordered item two

Another paragraph.

 : Definition term
    Definition description

Final paragraph after all lists.