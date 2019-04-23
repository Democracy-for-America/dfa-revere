require 'dotenv'
Dotenv.load

require 'sinatra'
require 'httparty'

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
  def self.client
    require 'mysql2'
    @client ||= Mysql2::Client.new(username: ENV['AK_USERNAME'], password: ENV["AK_PASSWORD"], host: ENV["AK_HOST"], database: ENV["AK_DB"])
  end

  def self.query sql
    Actionkit.client.query sql
  end
end

post "/:mobile_flow_id" do
  mobile_flow_id = params[:mobile_flow_id]
  json_params = JSON.parse(request.body.read)
  msisdn = json_params["phone"].to_s.gsub(/\D/, '')

  Thread.new do
    data = {
      "msisdns" => [msisdn],
      "mobileFlow" => mobile_flow_id
    }

    # Subscribe mobile phone number to Revere & send welcome message
    Revere.post("/messaging/sendContent", body: data.to_json)

    # Sync additional metadata to Revere, if present
    if json_params["metadata"]
      if json_params["metadata"]["name"]
        json_params["metadata"]["firstname"] = json_params["metadata"]["name"].split.first
        json_params["metadata"]["lastname"] = json_params["metadata"]["name"].split[1..-1].join(" ")
        json_params["metadata"]["fullname"] = json_params["metadata"].delete("name")
      end

      if json_params["metadata"]["zip"]
        json_params["metadata"]["zipcode"] = json_params["metadata"].delete("zip")
      end

      json_params["metadata"].each do |name, value|
        id = Revere.metadata_field_id(name) || Revere.create_metadata_field(name)
        data = { "id" => id, "value" => value }
        Revere.put("/subscriber/addMetadata/#{ msisdn }", body: data.to_json)
      end
    end
  end

  "Subscribed"
end
