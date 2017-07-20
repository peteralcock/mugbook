require 'rubygems'
require 'bundler'
require 'dotenv'
Bundler.require
require 'sinatra'
FACE_COLLECTION = "suspects"
Dotenv.load

Aws.config.update({
                      :region => ENV['AWS_REGION'],
                      :credentials => Aws::Credentials.new(ENV['AWS_ACCESS_KEY_ID'],ENV['AWS_SECRET_ACCESS_KEY'])

                  })

begin
  client = Aws::Rekognition::Client.new()
  client.create_collection({ collection_id: FACE_COLLECTION })
rescue => details
  puts details
end


get '/' do
  erb :faceapp
end



post '/upload/:photoid/:crime_id' do

  if params[:crime_id]
    crime_collection = params[:crime_id]

    begin
      client = Aws::Rekognition::Client.new()
      client.create_collection({ collection_id: params[:crime_id] })
    rescue => details
      puts details
    end
  else
    crime_collection = FACE_COLLECTION
  end


  begin
    client = Aws::Rekognition::Client.new()
    
    response = client.index_faces({
    collection_id: crime_collection,
    external_image_id: params[:photoid],
    image: {
      bytes: request.body.read.to_s
    }
  })

  rescue => details
    puts details
  end
  crime_label = crime_collection.to_s.gsub("_", " ")

  "Suspect has been added to #{crime_label.upcase}"

end

post '/compare/:crime_id' do
  content_type :json

  if params[:crime_id]
    crime_collection = params[:crime_id]

    begin
      client = Aws::Rekognition::Client.new()
      client.create_collection({ collection_id: params[:crime_id] })
    rescue => details
      puts details
    end
  else
    crime_collection = FACE_COLLECTION
  end


  response = client.search_faces_by_image({
                                              collection_id: crime_collection,
                                              max_faces: 1,
                                              face_match_threshold: 95,
                                              image: {
                                                  bytes: request.body.read.to_s
                                              }
                                          })
  if response.face_matches.count > 1
    {:message => "Too many faces found..."}.to_json
  elsif response.face_matches.count == 0
    {:message => "Suspect not found!"}.to_json
  else
    crime_label = crime_collection.to_s.gsub("_", " ")

    {:id => response.face_matches[0].face.external_image_id,:confidence => response.face_matches[0].face.confidence, :message => "WANTED FOR #{crime_label}".upcase}.to_json
  end
end


get '/collections' do
  client = Aws::Rekognition::Client.new()
  collections = client.list_collections({}).collection_ids
  response = collections
  response.to_json
end


get '/collection/:action' do
  client = Aws::Rekognition::Client.new()
  collections = client.list_collections({}).collection_ids
  case params[:action]
    when 'create'
      if !(collections.include? FACE_COLLECTION)
        response = client.create_collection({ collection_id: FACE_COLLECTION })
      end
    when 'delete'
      if (collections.include? FACE_COLLECTION)
        response = client.delete_collection({ collection_id: FACE_COLLECTION })
      end
  end
  redirect '/'
end
