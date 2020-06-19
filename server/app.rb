require 'rubygems'
require 'twilio-ruby'
require 'sinatra'
require 'dotenv'
require 'crack'
require 'json'
require 'net/http'
require 'open-uri'
require 'cgi'

# Load environment configuration
Dotenv.overload('.env.ts')

ACCOUNT_SID = ENV['TWILIO_ACCOUNT_SID']
API_KEY_SID = ENV['TWILIO_API_KEY']
API_KEY_SECRET = ENV['TWILIO_API_SECRET']
AUTH_TOKEN = ENV['TWILIO_AUTH_TOKEN']

# Generate a token for use in our Video application
get '/token' do
  identity = params[:identity] || 'identity'
  room_name = params[:room]

  # Create Video grant for our token
  grant = Twilio::JWT::AccessToken::VideoGrant.new
  grant.room = room_name
  # Create an Access Token
  begin
    token = Twilio::JWT::AccessToken.new(ACCOUNT_SID, API_KEY_SID, API_KEY_SECRET, [grant], identity: identity)
    # Generate the token
    return token.to_jwt
  rescue => error
    halt 403, error.message
  end
end

# Create video room
post '/create_room' do
  room_name = params[:room_name]
  record_room = params[:record_room] == "true" ? true : false
  client = Twilio::REST::Client.new(ACCOUNT_SID, AUTH_TOKEN)
  begin
    room = client.video.rooms.create(unique_name: room_name, record_participants_on_connect: record_room)
    return {"date_created":room.date_created, "date_updated":room.date_updated, "status":room.status, "sid":room.sid, "unique_name":room.unique_name, "duration":room.duration, "record_participants_on_connect":room.record_participants_on_connect, "url":room.url, "links":room.links}.to_json
  rescue => error
    halt 403, error.message
  end
end


# MARK - COMPOSITION CALLS
# Create video composition
post '/create_composition' do
  room_id = params[:room_id]
  participant_id = params[:participant_id]
  client = Twilio::REST::Client.new(API_KEY_SID, API_KEY_SECRET)

  email = (params[:email] || "").to_s
  
  begin
    composition = client.video.compositions.create(
      room_sid: room_id,
      audio_sources: '*',
      video_layout: {
        single: {
          video_sources: [participant_id]
        }
      },
     status_callback: "https://twilio-sample-6-18-20.herokuapp.com/composition_complete?email=#{email}",
     resolution: '1280x720',
     format: 'mp4'
    )
    return composition.sid
  rescue => error
    halt 403, error.message
  end
end

# Video composition callback
post '/composition_complete' do
  begin
    status = (params[:StatusCallbackEvent] || "").to_s
    if status == "composition-available"
      # HANDLE COMPOSITION CALLBACK HERE
      
    end
  rescue => error
    halt 403, error.message
  end
end

# Fetch composition media
get '/composition_media' do
  composition_id = params[:composition_id]
  client = Twilio::REST::Client.new(API_KEY_SID, API_KEY_SECRET)
  uri = "https://video.twilio.com/v1/Compositions/#{composition_id}/Media?Ttl=3600"
  begin
    response = client.request("video.twilio.com", 433, 'GET', uri)
    media_location = response.body['redirect_to']
    return media_location
  rescue => error
    halt 403, error.message
  end
end


# MARK - RECORDINGS CALLS
# Fetch recordings
get '/recordings' do
  room_id = params[:room_id]
  participant_id = params[:participant_id]
  grouping_sids = [room_id, participant_id].compact
  if grouping_sids.empty?
      halt 403, "No grouping sids specified"
  end
  client = Twilio::REST::Client.new(ACCOUNT_SID, AUTH_TOKEN)
  begin
    recordings = client.video.recordings.list(grouping_sid: grouping_sids)
    recording_array = []
    recordings.each do |record|
        recording_array << ({"date_created": record.date_created, "duration": record.duration, "links": record.links, "sid": record.sid, "grouping_sids": record.grouping_sids, "status": record.status, "url": record.url, "type": record.type})
    end
    return recording_array.to_json
  rescue => error
    halt 403, error.message
  end
end

# Fetch recorded media
get '/recorded_media' do
  room_id = params[:room_id]
  recording_id = params[:recording_id]
  client = Twilio::REST::Client.new(API_KEY_SID, API_KEY_SECRET)
  uri = 'https://video.twilio.com/v1/' +
        "Rooms/#{room_id}/" +
        "Recordings/#{recording_id}/" +
        'Media'
  begin
    response = client.request('video.twilio.com', 443, 'GET', uri)
    media_location = response.body['redirect_to']
    return media_location
  rescue => error
    halt 403, error.message
  end
end
