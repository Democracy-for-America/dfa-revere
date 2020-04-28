require 'httparty'
require 'mysql2'
require 'dotenv'
Dotenv.load

base_url = "https://app2.simpletexting.com/v1/group/contact/"
group = "DFA Main List"

# Build a set of all Simple Texting subscribers
subscribed_phone_numbers = HTTParty.get("#{ base_url }list/?group=#{ group }&token=#{ ENV['API_KEY'] }", { read_timeout: 600 }).
  parsed_response["response"]["contacts"].
  select { |contact| contact["status"] == "active" }.
  map{ |contact| contact["number"] }.to_set

client = Mysql2::Client.new(username: ENV['AK_USERNAME'], password: ENV['AK_PASSWORD'], host: ENV['AK_HOST'], database: ENV['AK_DB'])

# Select phone numbers and custom field values our ActionKit DB
# (This query selects the most recent vote of DFA staffers from the 2020 endorsement poll)
actions = client.query("
  SELECT * FROM (
    SELECT
      p.normalized_phone,
      u.id,
      u.first_name,
      u.last_name,
      u.state,
      u.zip,
      f.value
    FROM core_user u
    JOIN core_action a ON u.id = a.user_id
    JOIN core_actionfield f ON a.id = f.parent_id AND f.name = 'candidate'
    JOIN core_phone p ON u.id = p.user_id
    WHERE
      u.email LIKE '%@democracyforamerica.com' AND
      a.page_id = 10161 -- (2020 Dem Primary Endorsement)
    ORDER BY a.created_at DESC
  ) q
  GROUP BY normalized_phone
")

# Alternatively, data may be loaded from a CSV/spreadsheet -
# uncomment the following line to load data from the example_votes.csv file:
# actions = CSV.foreach('example_votes.csv', headers: true)

# Cross-reference ActionKit data with Simple Texting subscribers:
subscriber_actions = actions.to_a.select{ |vote| subscribed_phone_numbers.include? vote["normalized_phone"] }

# Sync each vote to Simple Texting
subscriber_actions.each_with_index do |row, i|
  # Note field naming conventions:
  #   firstName and lastName must be camel cased
  #   other custom fields (e.g. "ActionKit ID" & "Support 2020 Dem Primary")
  #   must be snake cased.
  params = {
    "token" => ENV['API_KEY'],
    "phone" => row['normalized_phone'],
    "actionkit_id" => row['id'],
    "firstName" => row['first_name'],
    "lastName" => row['last_name'],
    "state" => row['state'],
    "support_2020_dem_primary" => row['value'],
  }

  res = HTTParty.post("#{ base_url }update", body: params, options: { headers: { 'Content-Type' => 'application/x-www-form-urlencoded' } })
  puts "#{i} / #{actions.length}"
end
