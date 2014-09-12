require 'whenever'

every :day, :at => '2:00 am' do
   command "ruby commit_extraction.rb"
end
