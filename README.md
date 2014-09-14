git-commit-extraction
=====================

Script for extracting Git and Bitbucket commit data to CSV.

## Commit Analysis

Dependencies 

* Ruby 2.1.0

### List of libraries used 

* csv

* octoKit

* bitbucket_rest_api

* oauth

* oauth/consumer

* json

* octokit

* whenever

### Application execution instructions

### Input:

To get data from one or more repositories in Bitbucket, you should add repositories separates by comas to the environment variable called COMMIT_EXTRACTION_BITBUCKET_REPOS

For instance:

ENV["COMMIT_EXTRACTION_BITBUCKET_REPOS"] = repository_owner/repository_name,repository_owner/repository_name,...

To get data  from all repositories in Bitbucket, you should leave empty the environment variable called COMMIT_EXTRACTION_BITBUCKET_REPOS

To get data from a specific repository in GitHub, you should add repositories separates by comas to the environment variable called COMMIT_EXTRACTION_GITHUB_REPOS

For instance:

ENV["COMMIT_EXTRACTION_GITHUB_REPOS"] = repository_name,repository_name,...

To get data  from all repositories in GitHub, you should leave empty the environment variable called COMMIT_EXTRACTION_BITBUCKET_REPOS


### Output File:

The commit_extraction.csv file contains commits information from Bitbucket and GitHub Repositories from SSILAB Organization

| From | Repository | Branch  | SHA | FileName |Deletions|Additions|Changes| Author | Category | Message | Date |
|------|------------|---------|-----|----------|---------|---------|-------|--------|----------|---------|------|
|GitHub|satellite-usage-portalmaster|Master|8cdaed6abfa15157a017e71184a77d8940ca3b80|src/scripts/app.coffee|15|2|17|Luke Horvat|NEW|NEW: Created a "decimalPlaces” filter|2014-08-16 15:50:39 UTC

### Instructions to setup environment variables 

Below the link explains how accessing environment variables from Ruby, for execute the scripts
<http://ruby.about.com/od/rubyfeatures/a/envvar.htm>

#### GitHub 

GitHub is accessed by Token 

```ruby
@github = Octokit::Client.new(:access_token => ENV["GITHUB_ACCESS_TOKEN"])
```

#### Bitbucket 

Bitbucket is accessed by client id and client secret.

```ruby
@bitbucket = BitBucket.new do |config|
  config.client_id     = ENV["BITBUCKET_CLIENT_ID"]
  config.client_secret = ENV["BITBUCKET_CLIENT_SECRET"]
  config.adapter       = :net_http
end
```
