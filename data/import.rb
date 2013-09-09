REST_URL = 'http://localhost:7474/'
HEADER = { 'Content-Type' => 'application/json' }

%w{rubygems json faraday rdf rdf/ntriples}.each{|r| require r}

# make a connection to the Neo4j REST server
conn = Faraday.new(:url => REST_URL) do |builder|
	builder.adapter :net_http
end

# method to get existing node from the index, or create one
def get_or_create_node(conn, index, data)

	value = data.object.to_s.unpack('U*').pack('C*').force_encoding("UTF-8")
	uri = data.subject.to_s

	# look for node in the index
	#r = conn.get("/db/data/index/node/#{index}/name/#{URI.escape(value).gsub("?","%3F")}")
	r = conn.get("/db/data/index/node/#{index}/uri/#{CGI.escape(uri)}")
	node = (JSON.parse(r.body).first || {})['self'] if r.status == 200
	
	unless node
		# no indexed node found, so create a new one
		r = conn.post("/db/data/node", JSON.unparse({"name" => value, "uri" => uri}), HEADER)

		node = (JSON.parse(r.body) || {})['self'] if [200, 201].include? r.status
		# add new node to an index
		node_data = "{\"uri\" : \"#{node}\", \"key\" : \"name\", \"value\" : \"#{value}\"}"
		conn.post("/db/data/index/node/#{index}_names", node_data, HEADER)

		node_data = "{\"uri\" : \"#{node}\", \"key\" : \"uri\", \"value\" : \"#{uri}\"}"
		conn.post("/db/data/index/node/#{index}", node_data, HEADER)	

		node_data = "{\"uri\" : \"#{node}\", \"key\" : \"name\", \"value\" : \"#{value}\"}"		
		conn.post("/db/data/index/node/fulltext",node_data,HEADER)
		conn.post("/db/data/index/node/#{index}_fulltext",node_data,HEADER)
	end
	node
end

def create_relationship(conn,actor_uri,movie_uri)
	# create relationship between actor and movie
	r = conn.get("/db/data/index/node/actors/uri/#{CGI.escape(actor_uri)}")
	actor_node = (JSON.parse(r.body).first || {})['self'] if r.status == 200

	r = conn.get("/db/data/index/node/movies/uri/#{CGI.escape(movie_uri)}")
	movie_node = (JSON.parse(r.body).first || {})['self'] if r.status == 200

	if actor_node && movie_node
		conn.post("#{actor_node}/relationships",
			JSON.unparse({ :to => movie_node, :type => 'ACTED_IN' }), HEADER)
	end
end


puts "begin processing..."

data = '{"name":"fulltext", "config":{"type":"fulltext","provider":"lucene"}}'
res = conn.post("http://localhost:7474/db/data/index/node",data,HEADER)

puts "fulltext index created!" if res.status == 201

data = '{"name":"actors_fulltext", "config":{"type":"fulltext","provider":"lucene"}}'
res = conn.post("http://localhost:7474/db/data/index/node",data,HEADER)

puts "actors fulltext index created!" if res.status == 201

data = '{"name":"movies_fulltext", "config":{"type":"fulltext","provider":"lucene"}}'
res = conn.post("http://localhost:7474/db/data/index/node",data,HEADER)

puts "movies fulltext index created!" if res.status == 201

count = 0

RDF::Reader.open("data/actor_names.nt") do |reader|
	reader.each_statement do |statement|
		#puts "Subject: #{statement.subject} - Predicate: #{statement.predicate} - Object: #{statement.object}"
		actor_node = get_or_create_node(conn, 'actors', statement)
		puts "#{count} actors loaded" if (count += 1) % 100 == 0
	end
end

puts "done actors!"

count = 0

RDF::Reader.open("data/movie_titles.nt") do |reader|
	reader.each_statement do |statement|
		#puts "Subject: #{statement.subject} - Predicate: #{statement.predicate} - Object: #{statement.object}"
		movie_node = get_or_create_node(conn, 'movies', statement)
		puts "#{count} movies loaded" if (count += 1) % 100 == 0
	end
end

puts "done movies!"

count = 0

RDF::Reader.open("data/actor_movies.nt") do |reader|
	reader.each_statement do |statement|
		if statement.predicate == "http://data.linkedmdb.org/resource/movie/actor"
			#puts "Subject: #{statement.subject} - Predicate: #{statement.predicate} - Object: #{statement.object}"
			create_relationship(conn,statement.object.to_s,statement.subject.to_s)
			puts "#{count} relationships loaded" if (count += 1) % 100 == 0
		end
	end
end

puts "done!"