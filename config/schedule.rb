require 'whenever'

set :output, "/Users/Mgomez/git-commit-extraction/output/log.log"

every :day, :at => '2:00 am' do
   command "ruby commit_extraction.rb"
end

