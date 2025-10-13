= Complex Structure Test

This file tests complex combinations of elements.

== Mixed Content Section

Paragraph with @<b>{bold text} and a following list:

 * List item with @<code>{inline code}
 * Another item with @<href>{http://example.com, link}
 * Item with @<ruby>{日本語, にほんご} annotation

Table with formatted content:

//table[complex][Complex Table]{
Name	Description	Example
----
Bold	Bold formatting	b-tag
Italic	Italic formatting	i-tag
Code	Inline code	code-tag
//}

== Code with Comments

//list[complex-code][Complex Code Example]{
# This is a complex Ruby class
class DataProcessor
  def initialize(data)
    @data = data  # Store the input data
    @results = []
  end
  
  # Process the data with validation
  def process
    return false if @data.nil?
    
    @data.each do |item|
      # Validate each item before processing
      next unless valid_item?(item)
      
      processed = transform_item(item)
      @results << processed
    end
    
    true
  end
  
  private
  
  def valid_item?(item)
    !item.nil? && item.respond_to?(:to_s)
  end
  
  def transform_item(item)
    item.to_s.upcase
  end
end
//}

== Nested Structure

=== Subsection with Multiple Elements

Definition list with complex content:

 : @<b>{Configuration}
    System configuration using @<code>{config.yml} files
 : @<i>{Processing}
    Data processing with @<href>{https://ruby-lang.org, Ruby}
 : @<code>{Output}
    Final output in various formats

Image followed by explanation:

//image[architecture][System Architecture Diagram]

The architecture shown in @<img>{architecture} demonstrates the flow from input to output.

=== Another Subsection

Command sequence:

//cmd[Setup Commands]{
mkdir project
cd project
bundle init
bundle add review
//}

Final paragraph with @<strong>{important information} and @<em>{emphasized points}.