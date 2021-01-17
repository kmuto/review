Dir["#{__dir__}/review/*.rb"].each do |path|
  require "review/#{File.basename(path, '.rb')}"
end
