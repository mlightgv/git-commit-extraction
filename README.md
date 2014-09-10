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

### Application execution instructions

Output File:

The Repositories_Messagesy.csv file contains commits information from Bitbucket and GitHub Repositories from SSILAB Organization

| From | Repository | Branche | SHA | FileName | Author | Category | Message | Date |
|------|------------|---------|-----|----------|--------|----------|---------|------|
|GitHub|satellite-usage-portalmaster|Master|8cdaed6abfa15157a017e71184a77d8940ca3b80|src/scripts/app.coffee|Luke Horvat|NEW|NEW: Created a "decimalPlaces” filter|2014-08-16 15:50:39 UTC

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
