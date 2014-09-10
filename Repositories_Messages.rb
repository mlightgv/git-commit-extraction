# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
#  Create by: Mary Gomez
#  Date: 29/08/2014
#  Modified by:
#  Date: 
#  Description: Script for get data from Bitbucket and GitHub
#               (Commit's Messages)
# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
require 'bitbucket_rest_api'
require 'octokit'
require 'csv'
# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
#               Provide authentication credentials
# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

# @bitbucket = BitBucket.new login:'', password:''

if ENV["BITBUCKET_CLIENT_ID"].nil?
  puts "Couldn't find BITBUCKET_CLIENT_ID"
end
if ENV["BITBUCKET_CLIENT_SECRET"].nil?
  puts "Couldn't find BITBUCKET_CLIENT_SECRET"
end
if ENV["GITHUB_ACCESS_TOKEN"].nil?
  puts "Couldn't find GITHUB_ACCESS_TOKEN"
end

@bitbucket = BitBucket.new do |config|
  config.client_id     = ENV["BITBUCKET_CLIENT_ID"]
  config.client_secret = ENV["BITBUCKET_CLIENT_SECRET"]
  config.adapter       = :net_http
end

@github = Octokit::Client.new(:access_token => ENV["GITHUB_ACCESS_TOKEN"])

@github_organization        = "ssilab"
@github_commits_limit       = 100
@bitbucket_commits_limit    = 50 
@array_repositories_github  = Array.new
@filename                   = 'Repositories_Messagesy.csv'

# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
#                    Get Data
# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

CSV.open(@filename, "wb") do |csv|
  csv << ["From","Repository", "Branche", "SHA", "FileName", "Author", "Category", "Message", "Date"]
end

def category(message)
  case message[0,10].upcase 
    when /FIX/
      category_message = "FIXED"
    when /NEW/, /ADD/, /IMPLEMENT/
      category_message = "NEW"
    when /ENHANCE/, /CHANGE/, /BETTER/
      category_message = "ENHANCE"
    when /UPDATE/
      category_message = "UPDATE"
    when /LOOKS/
      category_message = "LOOKS"
    when /SPEED/
      category_message = "SPEED"
    when /DOC/
      category_message = "DOC"
    when /QUALITY/
      category_message = "QUALITY"
    when /CONFIG/
      category_message = "CONFIG"
    when /TEST/
      category_message = "TEST"
    when /SHAME/, /REMOVE/
      category_message = "SHAME"
    when /DEPLOY/
      category_message = "DEPLOY"
    else
      category_message = "NOT CATEGORY"
  end
  return category_message
end

def bitbucket_commits_count(repo_owner, repo_slug)
  begin
    commits = @bitbucket.repos.changesets.list repo_owner, repo_slug, :limit => '1' 
    commits_count = commits[:count]
    return commits_count
  rescue 
    return 0
  end
end

def bitbucket_commits_by_page(num_pages, repo_owner, repo_slug, start_commit_node)
  if num_pages == 1
    commits = @bitbucket.repos.changesets.list repo_owner, repo_slug, 
                                                 :limit => @bitbucket_commits_limit
  else
    commits = @bitbucket.repos.changesets.list repo_owner, repo_slug, 
                                                 :limit => @bitbucket_commits_limit, 
                                                 :start => start_commit_node
  end 
  return commits
end

def bitbucket_commits_is_last_page(commits_count, num_pages)
   if commits_count - num_pages <= @bitbucket_commits_limit
      is_last_page = true
    else
      is_last_page = false
    end
    return is_last_page
end

def bitbucket_commits_details(repo_slug, commits, is_last_page)
  start_commit_node = ''
  num_node = 1
  CSV.open(@filename, "ab") do |csv|
    commits.changesets.each  do |change|
      #change.files.each do |file|
        if num_node == 1 
          start_commit_node = change.node 
        end
        if start_commit_node != change.node || is_last_page
          commit_repository = repo_slug             
          commit_branche    = change.branche     
          commit_sha        = change.raw_node       
          commit_fileName  = '' #file.file             
          commit_author     = change.author         
          commit_message    = change.message        
          commit_category   = category(commit_message)
          commit_date       = change.timestamp.to_s       
          csv << ["Bitbucket", commit_repository, commit_branche, commit_sha, commit_fileName, commit_author, commit_category.to_s, commit_message, commit_date] 
        end
        num_node = num_node + 1
      #end 
    end
  end
  return start_commit_node
end

def bitbucket_commits(repo_owner, repo_slug)
  commits_count     = bitbucket_commits_count(repo_owner, repo_slug)
  start_commit_node = ''
  num_pages         = 1
  while num_pages <= commits_count  do
    commits           = bitbucket_commits_by_page(num_pages, repo_owner, repo_slug, start_commit_node)
    is_last_page      = bitbucket_commits_is_last_page(commits_count, num_pages)
    start_commit_node = bitbucket_commits_details(repo_slug, commits, is_last_page)
    num_pages         += @bitbucket_commits_limit
  end
end

def bitbucket_repositories
  @bitbucket.repos.list do |repo|
    if !repo.is_private && @array_repositories_github.include?(repo.name) then
      next
    end
    bitbucket_commits(repo.owner, repo.slug)
  end 
end

def github_commits_details(repo_full_name, branche,  sha)
  CSV.open(@filename, "ab") do |csv|
    commit = @github.commit repo_full_name, sha
    #commit[:files].each do |item|
      commit_repository = repo_full_name                    
      commit_branche    = branche            
      commit_sha        = commit.sha                   
      commit_fileName   = '' #item[:filename]                
      commit_author     = commit.commit.author.name     
      commit_message    = commit.commit.message          
      commit_category   = category(commit_message)
      commit_date       = commit.commit.author.date.to_s 
      puts commit_repository + ' ' + commit_branche + ' ' + commit_sha + ' ' + commit_date
      csv << ["GitHub",commit_repository, commit_branche, commit_sha, commit_fileName, commit_author, commit_category.to_s, commit_message, commit_date] 
    #end
  end
end


def github_commits_by_page(repo_full_name, branche)
  start_commit_sha = '' 
  num_page = 1
  loop do
    commits = @github.commits repo_full_name, branche, { page: num_page, per_page: @github_commits_limit }
    commits_size = commits.size
    for i in 0..commits.size - 1
      github_commits_details(repo_full_name, branche, commits[i][:sha])
    end 
    break if commits_size != 0
  end
end

def github_commits_branches(repo_full_name)
  branches = @github.branches repo_full_name
  for i in 0..branches.size - 1
     github_commits_by_page(repo_full_name, branches[i][:name])
  end 
end

def github_repositories
  x = 0
  repos = @github.organization_repositories @github_organization, { type: 'sources' } 
  repos.each do |repo|
    @array_repositories_github[x] = repo.name
    x += 1 
    github_commits_branches(repo.full_name)
  end
end



#bitbucket_commits('itig', 'prompa-web')
#bitbucket_repositories



#github_commits_branches('ssilab/prompa-web')
github_commits_branches('ssilab/mbt-fleet-visualisation-web')
#github_repositories




  
    
   



