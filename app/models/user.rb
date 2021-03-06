class User < ActiveRecord::Base
  attr_accessor :github_user

  has_many :repositories
  has_many :pull_requests

  def list_repositories
    github_repositories.each do |repo|
      repositories.find_or_create_by(full_name: repo.full_name)
    end
    repositories
  end

  def github_repositories
    Rails.cache.fetch("#{cache_key}/repositories", expires_in: 1.year) do
      github_user.repositories(nil, per_page: 100)
    end
  end

  def best_pull_request
    repos = pull_requests.where(checked: false).select(:repo).uniq.pluck(:repo)
    pulls_repos = pull_requests.where(checked: false).where(repo: repos.shuffle.first).order(:pull_id).first
  end

  def populate_pull_requests
    github_repositories.each do |repo|
      n = 0
      loop do
        length = 0
        Rails.cache.fetch("#{cache_key}/repositories/pulls/#{repo.full_name}?page=#{n}", expires_in: 1.year) do
          pulls = github_user.pull_requests(repo.full_name, state: 'all', per_page: 100, page: n) rescue []
          pulls.each do |pr|
            pull = pull_requests.find_or_create_by(pull_id: pr.number, repo: repo.full_name, checked: false)
            pull.title = pr.title
            pull.url = pr.html_url
            pull.save
            pull.populate_files
          end
          length = pulls.length
        end
        n = n + 1
        break if length != 100
      end
    end
  end
end
