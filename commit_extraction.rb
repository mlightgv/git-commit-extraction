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
require 'whenever'
require 'fileutils'
require 'oauth'
require 'oauth/consumer'
require 'json'

# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
#                    Message categorization
# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

def category(message)
  case message[0,10].upcase
    when /FIX/
      category_message = "FIX"
    when /NEW/, /ADD/, /IMPLEMENT/
      category_message = "NEW"
    when /ENHANCE/, /CHANGE/, /BETTER/
      category_message = "ENHANCE"
    when /LOOKS/
      category_message = "LOOKS"
    when /SPEED/
      category_message = "SPEED"
    when /DOC/
      category_message = "DOC"
    when /QUALITY/
      category_message = "QUALITY"
    when /CONF/
      category_message = "CONFIG"
    when /TEST/
      category_message = "TEST"
    else
      category_message = "UNCATEGORISED"
  end
  return category_message
end

# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
#                    Get Data From Bitbucket
# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

def bitbucket_commits_count(repo_owner, repo_slug)
  begin
    commits = @bitbucket.repos.changesets.list repo_owner, repo_slug, :limit => '1'
    commits_count = commits[:count]
    return commits_count
  rescue
    return 0
  end
end

def bitbucket_commits_by_page(num_page, repo_owner, repo_slug, start_commit_node)
  if num_page == 1
    commits = @bitbucket.repos.changesets.list repo_owner, repo_slug,
                                                 :limit => @bitbucket_commits_limit
  else
    commits = @bitbucket.repos.changesets.list repo_owner, repo_slug,
                                                 :limit => @bitbucket_commits_limit,
                                                 :start => start_commit_node
  end
  return commits
end

def bitbucket_commits_is_last_page(commits_count, num_page)
   if commits_count - num_page <= @bitbucket_commits_limit
      is_last_page = true
    else
      is_last_page = false
    end
    return is_last_page
end

def bitbucket_commits_details(repo_owner, repo_slug, commits, is_last_page)
  start_commit_node = ''
  num_node = 1
  CSV.open(@filename, "ab") do |csv|
    commits.changesets.each  do |change|
      change.files.each do |file|
        if num_node == 1
          start_commit_node = change.node
        end
        if start_commit_node != change.node || is_last_page
          commit_repository = repo_slug
          commit_branche    = change.branche
          commit_sha        = change.raw_node
          commit_fileName   = file.file
          commit_author     = change.author
          commit_message    = change.message
          commit_category   = category(commit_message)
          commit_date       = change.timestamp.to_s
          response = @bitbucket_consumer.request(:get, "https://bitbucket.org/api/1.0/repositories/#{repo_owner}/#{repo_slug}/changesets/#{change.raw_node}/diffstat/")
          hash = JSON.parse(response.body)
          for i in 0..hash.size - 1
            @commit_fileName = hash[i]["file"]
            stat             = hash[i]["diffstat"]
            stat.each do |item|
              if item[0] == 'removed'
                @commit_deletions = item[1]
              else
                @commit_additions = item[1]
              end
                @commit_changes   = @commit_deletions.to_i + @commit_additions.to_i
            end
            csv << ["Bitbucket", commit_repository, commit_branche, commit_sha, commit_fileName, @commit_deletions, @commit_additions, @commit_changes, commit_author, commit_category.to_s, commit_message, commit_date]
          end
        end
        num_node = num_node + 1
      end
    end
  end
  return start_commit_node
end

def bitbucket_commits(repo_owner, repo_slug)
  commits_count     = bitbucket_commits_count(repo_owner, repo_slug)
  start_commit_node = ''
  num_page         = 1
  while num_page <= commits_count  do
    commits           = bitbucket_commits_by_page(num_page, repo_owner, repo_slug, start_commit_node)
    is_last_page      = bitbucket_commits_is_last_page(commits_count, num_page)
    start_commit_node = bitbucket_commits_details(repo_owner, repo_slug, commits, is_last_page)
    num_page         += @bitbucket_commits_limit
  end
end

def extract_all_bitbucket_repositories
  @bitbucket.repos.list do |repo|
    if !repo.is_private && @array_repositories_github.include?(repo.name) then
      next
    end
    bitbucket_commits(repo.owner, repo.slug)
  end
end

# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
#                    Get Data From GitHub
# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

def github_commits_details(repo_full_name, branche,  sha)
  CSV.open(@filename, "ab") do |csv|
    commit = @github.commit repo_full_name, sha
    commit[:files].each do |item|
      commit_repository = repo_full_name
      commit_branche    = branche
      commit_sha        = commit.sha
      commit_fileName   = item[:filename]
      commit_additions  = item[:additions].to_s
      commit_deletions  = item[:deletions].to_s
      commit_changes    = item[:changes].to_s
      commit_author     = commit.commit.author.name
      commit_message    = commit.commit.message
      commit_category   = category(commit_message)
      commit_date       = commit.commit.author.date.to_s
      csv << ["GitHub",commit_repository, commit_branche, commit_sha, commit_fileName, commit_deletions, commit_additions, commit_changes, commit_author, commit_category.to_s, commit_message, commit_date]
    end
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

def extract_all_github_repositories
  x = 0
  repos = @github.organization_repositories @github_organization, { type: 'sources' }
  repos.each do |repo|
    @array_repositories_github[x] = repo.name
    x += 1
    github_commits_branches(repo.full_name)
  end
end

# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
#                    Script Execution
# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

if ARGV[0]
  @output_dir = ARGV[0]

  unless Dir.exists? @output_dir
    puts "ERROR: Output directory #{@output_dir} does not exist."
    exit
  end
else
  puts <<-eos
  ERROR: No output directory specified

  Example usage:
  ruby commit_extraction.rb [output_dir]
  eos
  exit
end

# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
#                    Environment Variables
# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
if ENV["COMMIT_EXTRACTION_BITBUCKET_CLIENT_ID"].nil?
  puts "Couldn't find COMMIT_EXTRACTION_BITBUCKET_CLIENT_ID"
end
if ENV["COMMIT_EXTRACTION_BITBUCKET_CLIENT_SECRET"].nil?
  puts "Couldn't find COMMIT_EXTRACTION_BITBUCKET_CLIENT_SECRET"
end
if ENV["COMMIT_EXTRACTION_GITHUB_ACCESS_TOKEN"].nil?
  puts "Couldn't find COMMIT_EXTRACTION_GITHUB_ACCESS_TOKEN"
end
if ENV["COMMIT_EXTRACTION_GITHUB_REPOS"].nil?
  puts "Couldn't find COMMIT_EXTRACTION_GITHUB_REPOS"
end
if ENV["COMMIT_EXTRACTION_BITBUCKET_REPOS"].nil?
  puts "Couldn't find COMMIT_EXTRACTION_BITBUCKET_REPOS"
end
if ENV["COMMIT_EXTRACTION_ORGANIZATION"].nil?
  puts "Couldn't find COMMIT_EXTRACTION_ORGANIZATION"
end

# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
#                    Header File
# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

if ENV["COMMIT_EXTRACTION_BITBUCKET_CLIENT_ID"] && ENV["COMMIT_EXTRACTION_BITBUCKET_CLIENT_ID"]
  @bitbucket = BitBucket.new do |config|
    config.client_id     = ENV["COMMIT_EXTRACTION_BITBUCKET_CLIENT_ID"]
    config.client_secret = ENV["COMMIT_EXTRACTION_BITBUCKET_CLIENT_SECRET"]
    config.adapter       = :net_http
  end

  @bitbucket_consumer = OAuth::Consumer.new(ENV["COMMIT_EXTRACTION_BITBUCKET_CLIENT_ID"],
                                            ENV["COMMIT_EXTRACTION_BITBUCKET_CLIENT_SECRET"],
                                            {:site=>"https://bitbucket.org"})
end

@github = Octokit::Client.new(:access_token => ENV["COMMIT_EXTRACTION_GITHUB_ACCESS_TOKEN"])

# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\
#                    initialization variables
# //\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\//\\

@github_organization        = ENV["COMMIT_EXTRACTION_ORGANIZATION"]
@github_commits_limit       = 100
@bitbucket_commits_limit    = 50
@array_repositories_github  = Array.new

@filename = "#{@output_dir}/commit-extraction.csv"

CSV.open(@filename, "wb") do |csv|
  csv << ["From","Repository", "Branch", "SHA", "FileName", "Deletions", "Additions", "Changes", "Author", "Category", "Message", "Date"]
end

github_repositories     = ENV["COMMIT_EXTRACTION_GITHUB_REPOS"] ?     ENV["COMMIT_EXTRACTION_GITHUB_REPOS"].split(",")    : []
bitbucket_repositories  = ENV["COMMIT_EXTRACTION_BITBUCKET_REPOS"] ?  ENV["COMMIT_EXTRACTION_BITBUCKET_REPOS"].split(",") : []

current_time = Time.now
puts  "Start " + current_time.strftime("%Y-%m-%d %H:%M:%S")

if github_repositories.empty?
  extract_all_github_repositories
else
  github_repositories.each do |repo|
    github_commits_branches(repo)
  end
end

if @bitbucket
  if bitbucket_repositories.empty?
    extract_all_bitbucket_repositories
  else
    bitbucket_repositories.each do |repo|
      owner, repo_name = repo.split "/"
      bitbucket_commits(owner, repo_name)
    end
  end
end

current_time = Time.now
puts "End " + current_time.strftime("%Y-%m-%d %H:%M:%S")
