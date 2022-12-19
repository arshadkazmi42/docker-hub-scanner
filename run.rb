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
    docker_tags = DockerTags.new
    docker_layers = DockerLayers.new

    for repo in @repositories

      repo_name = repo["repo_name"]
      tags = docker_tags.get(repo_name)

      for tag in tags["results"]

        tag_name = tag["name"]
        layers = docker_layers.get(repo_name, tag_name)

        for layer in layers
          
          for layer_data in layer["layers"]
            
            File.write("#{@query}.txt", layer_data["instruction"], mode: "a")
          end
        end

      end
    end
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

  def get(repo)
    call_api(repo)
  end

  def call_api(repo, page=1)
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


class Api
  def call(url, params)
    puts url, params
    
    uri = URI(url)
    uri.query = URI.encode_www_form(params)
    
    https = Net::HTTP.new(uri.host, uri.port)
    https.use_ssl = true

    request = Net::HTTP::Get.new(uri)
    response = https.request(request)

    JSON.parse(response.body)
  end
end


Run.new(ARGV[0])