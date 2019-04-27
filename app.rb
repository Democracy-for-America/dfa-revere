require 'dotenv'
Dotenv.load

require 'sinatra'
require 'httparty'
require 'mysql2'

# Configure server
set :bind, '0.0.0.0'

class Revere
  include HTTParty
  base_uri 'https://mobile.reverehq.com/api/v1'
  headers({
    "accept" => "application/json",
    "content-type" => "application/json",
    "Authorization" => ENV['REVERE_API_KEY']
  })

  def self.metadata_field_id name
    field = Revere.get("/metadata?size=-1").parsed_response["collection"].select{ |m| m["name"] == name }
    field.size > 0 ? field[0]["id"] : nil
  end

  def self.create_metadata_field name
    data = {
      "eventUrl": nil,
      "format": ".{1,100}",
      "multiValue": false,
      "name": name,
      "status": "ACTIVE",
      "type": "STRING",
      "validValues": nil
    }

    Revere.post("/metadata", body: data.to_json).parsed_response["id"]
  end
end

class Actionkit
  include HTTParty
  base_uri ENV['AK_API_PATH']
  basic_auth ENV['AK_API_USERNAME'], ENV['AK_API_PASSWORD']

  def self.set_userfield user_id, name, value
    existing_field = Actionkit.get("/rest/v1/userfield/?user=#{ user_id }&name=#{ name }").parsed_response["objects"][0]

    if existing_field
      Actionkit.put(existing_field['resource_uri'], body: {name: name, value: value})
    else
      Actionkit.post("/rest/v1/userfield/", body: {user: "/rest/v1/user/#{ user_id }/", name: name, value: value})
    end
  end
end

# Global variables
set :next_phone_sql, File.read('next_phone.sql')
set :revere_metadata_ids, {}

# Syncs a single phone number to Revere
# Returns 0 if an unsynced phone number is available, 60 if not
def sync_single_phone
  client = Mysql2::Client.new({
    username: ENV['AK_USERNAME'],
    password: ENV["AK_PASSWORD"],
    host: ENV["AK_HOST"],
    database: ENV["AK_DB"]
  })
  query_result = client.query(settings.next_phone_sql)
  client.close

  if query_result.first.nil?
    return 60
  else
    msisdn = query_result.first["msisdn"].to_s.gsub(/\D/, '')

    data = {
      "msisdns" => [msisdn],
      "mobileFlow" => query_result.first["revere_mobile_flow_id"] || ENV['DEFAULT_REVERE_MOBILE_FLOW_ID']
    }

    Revere.post("/messaging/sendContent", body: data.to_json)

    ["DFA ActionKit ID", "First", "Last", "email", "zipcode"].each do |field_name|
      settings.revere_metadata_ids[field_name] ||= (Revere.metadata_field_id(field_name) || Revere.create_metadata_field(field_name))
      data = { "id" => settings.revere_metadata_ids[field_name], "value" => query_result.first[field_name] }
      Revere.put("/subscriber/addMetadata/#{ msisdn }", body: data.to_json)
    end

    actionkit_id = query_result.first['DFA ActionKit ID']
    timestamp = query_result.first['created_at'].to_s[0...19]
    Actionkit.set_userfield actionkit_id, 'most_recent_revere_sync', timestamp

    puts "phone: #{ msisdn }, actionkit_id: #{ actionkit_id }"
    return 0
  end
end

if ENV['RACK_ENV'] == 'production'
  Thread.new do
    while true
      sleep sync_single_phone
    end
  end
end

get "/" do
  "Hello world!"
end

get "/queue" do
  client = Mysql2::Client.new({
    username: ENV['AK_USERNAME'],
    password: ENV["AK_PASSWORD"],
    host: ENV["AK_HOST"],
    database: ENV["AK_DB"]
  })
  result = client.query(File.read('queue_length.sql')).first.to_s
  client.close
  return result
end
