require 'dotenv'
Dotenv.load

require 'sinatra'
require 'objspace'
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

  def self.query sql
    Actionkit.post("/rest/v1/report/run/sql/", body: { query: "#{ sql } -- cache buster: #{ Time.now.to_f } #{ rand }" })
  end

  def self.update_actionfield id, **opts
    Actionkit.put("/rest/v1/actionfield/#{ id }/", body: opts)
  end

  def self.set_userfield user_id, **opts
    existing_field = Actionkit.get("/rest/v1/userfield/?user=#{ user_id }&name=#{ opts[:name] }").parsed_response["objects"][0]

    if existing_field
      Actionkit.put(existing_field['resource_uri'], body: {name: opts[:name], value: opts[:value]})
    else
      Actionkit.post("/rest/v1/userfield/", body: {user: "/rest/v1/user/#{ user_id }/", name: opts[:name], value: opts[:value]})
    end
  end
end

# Global variables
set :next_phone_sql, File.read('next_phone.sql').gsub(/\n/, ' ')
set :queue_length_sql, File.read('queue_length.sql').gsub(/\n/, ' ')
set :revere_metadata_ids, {}
set :recently_synced, []

# Syncs a single phone number to Revere
# Returns 0 if an unsynced phone number is available, 60 if not
def sync_single_phone
  response_1 = Actionkit.query(Sinatra::Application.settings.next_phone_sql)

  if response_1.code == 200 && response_1.parsed_response.class == Array && response_1.parsed_response.length > 0
    params = {
      "token"                 => ENV['API_KEY'],
      "group"                 => "DFA Main List",
      "phone"                 => response_1.parsed_response[0][0].to_s.gsub(/\D/, ''),
      "actionkit_id"          => response_1.parsed_response[0][1].to_s,
      "firstName"             => response_1.parsed_response[0][2].to_s,
      "lastName"              => response_1.parsed_response[0][3].to_s,
      "email"                 => response_1.parsed_response[0][4].to_s,
      "state"                 => response_1.parsed_response[0][5].to_s,
      "zip"                   => response_1.parsed_response[0][6].to_s,
      "actionfield_id"        => response_1.parsed_response[0][7].to_s
    }

    response_2 = Actionkit.update_actionfield params["actionfield_id"], name: "sms_opt_in_synced"

    if response_2.code == 204 && !settings.recently_synced.include?(params["actionfield_id"])
      settings.recently_synced << params["actionfield_id"]
      settings.recently_synced.shift while ObjectSpace.memsize_of(settings.recently_synced) > 1000000
      params.delete "actionfield_id"
      HTTParty.post("https://app2.simpletexting.com/v1/group/contact/add", body: params, options: { headers: { 'Content-Type' => 'application/x-www-form-urlencoded' } })
      Actionkit.set_userfield params['actionkit_id'], name: 'most_recent_revere_sync', value: Time.now.to_s[0...19]
      puts "phone: #{ params["phone"] }, actionkit_id: #{ params['actionkit_id'] }"
    end

    return 0
  else
    return 60
  end
end

if ENV['RACK_ENV'] == 'production'
  Thread.new do
    while true
      begin
        sleep sync_single_phone
      rescue
      end
    end
  end
end

get "/" do
  "Hello world!"
end

get "/queue" do
  response = Actionkit.query(Sinatra::Application.settings.queue_length_sql)
  return response.parsed_response[0][0]
end
