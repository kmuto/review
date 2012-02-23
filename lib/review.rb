Dir["#{File.dirname(__FILE__)}/review/*.rb"].sort.each do |path|
  require "review/#{File.basename(path, '.rb')}"
end
