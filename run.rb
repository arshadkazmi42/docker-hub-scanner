require 'net/http'
require 'uri'
require 'json'

class Run

  def initialize(query, flags=nil)
    raise "Required parameter query" unless query

    @query = query
    @flags = Flags.new(flags)
    @repositories = []
    @tags = []

    start
  end

  def start
    process_repositories
    process_tags unless @flags.only_tags?
    process_only_tags if @flags.only_tags?
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
    docker_tags = DockerTags.new
    docker_layers = DockerLayers.new

    for repo in @repositories

      repo_name = repo["repo_name"]

    
      tags_count = docker_tags.get_count(repo_name)

      tag_pages = 1
      tag_pages = (tags_count / 100) + 1 if tags_count > 0

      tag_page=1
      while tag_page <= tag_pages
        tags = docker_tags.get(repo_name, tag_page)

        for tag in tags["results"]

          process_user(tag)

          tag_name = tag["name"]
          layers = docker_layers.get(repo_name, tag_name)

          docker_repo = "\n-------------\nDocker Repo: #{repo_name} - #{tag_name}\n-------------\n"
          File.write("#{@query}.txt", "#{docker_repo}", mode: "a")

          for layer in layers
            
            for layer_data in layer["layers"]
              
              File.write("#{@query}.txt", "#{layer_data["instruction"]}\n", mode: "a")
            end if is_valid_layers(layer)
          end

        end if is_valid_tags(tags)

        tag_page = tag_page + 1 
      end
    end
  end

  def process_only_tags
    docker_tags = DockerTags.new
    docker_layers = DockerLayers.new

    for repo in @repositories

      repo_name = repo["repo_name"]

    
      tags_count = docker_tags.get_count(repo_name)

      tag_pages = 1
      tag_pages = (tags_count / 100) + 1 if tags_count > 0

      tag_page=1
      while tag_page <= tag_pages
        tags = docker_tags.get(repo_name, tag_page)

        for tag in tags["results"]

          tag_name = tag["name"]

          docker_repo = "\n#{repo_name}:#{tag_name}\n"
          File.write("#{@query}.txt", "#{docker_repo}", mode: "a")

        end if is_valid_tags(tags)

        tag_page = tag_page + 1 
      end
    end
  end
 
  
  def process_user(tag)
    puts tag["last_updater_username"]
    File.write("#{@query}_users.txt", "#{tag["last_updater_username"]}\n", mode: "a")
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
    @api.call("https://hub.docker.com/v2/search/repositories", {
      :page => page,
      :query => @query,
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

class DockerLayers

  def initialize
    @api = Api.new
  end

  def get(repo, tag)
    call_api(repo, tag)
  end

  def call_api(repo, tag)
    @api.call("https://hub.docker.com/v2/repositories/#{repo}/tags/#{tag}/images", {
      :ordering => "last_updated",
    })
  end

end

class Flags
  def initialize(flags)
    @flags = flags
  end

  def only_tags?
    @flags == "--only-tags"
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


Run.new(ARGV[0], ARGV[1])
