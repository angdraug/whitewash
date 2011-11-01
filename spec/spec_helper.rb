require 'rspec'
$LOAD_PATH.unshift(File.expand_path("../lib", File.dirname(__FILE__)))
require 'whitewash'

class Whitewash
  remove_const :PATH
  PATH = [ File.expand_path("../data/whitewash", File.dirname(__FILE__)) ]
end
