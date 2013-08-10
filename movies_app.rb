require 'sinatra/base'
require 'sinatra/contrib'
require 'sinatra/reloader'

class App < Sinatra::Base

  configure :development do |config|
    register Sinatra::Reloader
  end
  
  set :haml, :format => :html5 
  set :app_file, __FILE__

  get '/' do
    @neoid = params["neoid"]
    haml :index
  end
  
  get '/search' do 
    content_type :json
    neo = Neography::Rest.new 

    result = neo.get_node_index("actors_names", "name", params[:term])   

    if result
      node = result.first
      data = node["data"]
      node_id = node["self"].split("/").last

      return [{label: data["name"], value: node_id}].to_json
    end

  end

  get '/edges/:id' do
    content_type :json
    neo = Neography::Rest.new    

    node = neo.get_node(params[:id])

    if node
      if node["data"]["uri"].match("http://data.linkedmdb.org/resource/film/")
        rel_type = "start"
        node_type = "Movie"
        rel_node_type = "Person"
      else
        rel_type = "end"
        node_type = "Person"
        rel_node_type = "Movie"
      end
      nodes = []
      relationships = neo.get_node_relationships(node)
      relationships.each {|rel|
        nodes << neo.get_node(rel[rel_type])
      }
      nodes.collect{|n|
        {
          "source" => node["self"].split("/").last, 
          "source_data" => {
            :label => node["data"]["name"], 
            :description => node["data"]["name"],
            :type => node_type
            },
          "target" => n["self"].split("/").last, 
          "target_data" => {
            :label => n["data"]["name"], 
            :description => n["data"]["name"],
            :type => rel_node_type
            }
        }
      }.to_json
    end

  end

end