# This script randomly assigns each SimpleTexting subscriber one of the following test_group fields
test_groups = ["short", "long"]

require 'httparty'
require 'dotenv'
Dotenv.load

base_url = "https://app2.simpletexting.com/v1/group/contact/"
group = "DFA Main List"
token = "redacted"

contacts = HTTParty.get("#{ base_url }list/?group=#{ group }&token=#{ token }").
  parsed_response["response"]["contacts"].
  select { |contact| contact["status"] == "active" }

contacts.each_with_index do |contact, i|
  params = {
    "token" => token,
    "phone" => contact["number"],
    "test_group" => test_groups.shuffle[0]
  }

  res = HTTParty.post("#{ base_url }update", body: params, options: { headers: { 'Content-Type' => 'application/x-www-form-urlencoded' } })
  
  puts "#{i} / #{contacts.length}"
end
