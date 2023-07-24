require 'net/http'
require 'uri'
require 'json'

class Run

  def initialize(query)
    raise "Required parameter query" unless query

    @query = query
    @repositories = []
    @tags = []

    start
  end

  def start
    process_repositories
    process_tags
  end

  def process_repositories
    docker_repositories = DockerRepositories.new(@query)
    
    repositories_count = docker_repositories.get_count

    repository_pages = 1
    repository_pages = (repositories_count / 100) + 1 if repositories_count > 0

    repository_page=1
    while repository_page <= repository_pages
      
      repositories = docker_repositories.get(repository_page)
      @repositories.push(*repositories["results"])
      
      repository_page = repository_page + 1 
    end
  end

  def process_tags
    MAX_TAGS = 1

    docker_tags = DockerTags.new

    for repo in @repositories

      repo_name = "#{repo["namespace"]}/#{repo["name"]}"
    
      tags_count = docker_tags.get_count(repo_name)

      tag_page = 1
      tag_pages = 1
      tags_found = 0
      tag_pages = (tags_count / 100) + 1 if tags_count > 0

      while tag_page <= tag_pages
        break if tags_found >= MAX_TAGS  # Process only first two tags
        tags = docker_tags.get(repo_name, tag_page)
        for tag in tags["results"]
          break if tags_found >= MAX_TAGS # Process only first two tags
          tag_name = tag["name"]
          tag_size = tag["full_size"]/(1000 * 1000 * 1000) # Convert the size to GB
          docker_repo = "#{repo_name}:#{tag_name}\n"
          File.write("#{@query}.txt", "#{docker_repo}", mode: "a") unless tag_size > 1 # Use tag only if size less than or equal to 1 gb
          tags_found = tags_found + 1
        end if is_valid_tags(tags)

        tag_page = tag_page + 1 
      end
    end
  end
  
  def is_valid_tags(tags)
    tags.is_a?(Hash) && tags.has_key?("results")
  end

  def is_valid_layers(layers)
    layers.is_a?(Hash) && layers.has_key?("layers")
  end
end


class DockerRepositories

  def initialize(query)
    @query = query

    @api = Api.new
  end

  def get_count
    call_api["count"]
  end

  def get(page=1)
    call_api(page)
  end

  def call_api(page=1)
    @api.call("https://hub.docker.com/v2/repositories/#{@query}", {
      :page => page,
      :page_size => 100,
      :ordering => "last_updated",
    })
  end
end


class DockerTags

  def initialize
    @api = Api.new
  end

  def get_count(repo, page=1)
    call_api(repo, page)["count"]
  end

  def get(repo, page=1)
    call_api(repo, page)
  end

  def call_api(repo, page)
    @api.call("https://hub.docker.com/v2/repositories/#{repo}/tags", {
      :page => page,
      :page_size => 100,
      :ordering => "last_updated",
    })
  end

end

class Api
  def call(url, params)
    puts url, params
    
    uri = URI(url)
    uri.query = URI.encode_www_form(params)
    
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    response = https.request(request)

    throttle(response.each_header.to_h)

    JSON.parse(response.body)
  end

  def throttle(headers)
    if headers.has_key?("x-ratelimit-remaining")
      rate_remaining = headers["x-ratelimit-remaining"].to_i
      if rate_remaining.to_i % 50 == 0
        seconds = rand(30...60)
        puts "Throttling for #{seconds} seconds"
        sleep rand(seconds)
      end 
    end
  end
end


Run.new(ARGV[0])
