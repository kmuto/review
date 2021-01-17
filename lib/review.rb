Dir["#{__dir__}/review/*.rb"].sort.each do |path|
  require "review/#{File.basename(path, '.rb')}"
end
