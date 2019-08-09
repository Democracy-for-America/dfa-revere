This application acts as an endpoint to subscribe mobile phone numbers to Revere Mobile & sync accompanying subscriber metadata.

**Example use:**

```
curl -X POST localhost:4567/mobile_flow_id --data '{"phone": "(802) 555-0188", "metadata": {"Favorite vegetable": "Rutabaga"}}'
```

(Replace the mobile_flow_id slug of the URL with the 24-character hexadecimal ID of the Revere mobile flow you wish to trigger.)

If running locally, make a copy of the `.env.example` file, rename it to `.env`, and set the `REVERE_API_KEY` environment variable. If running on Heroku, use the built-in interface to set a `REVERE_API_KEY` environment variable.

**Running scripts:**

Suppose you want to tag subscribers in Revere for easy targeting. In this example, we'll tag DFA staff members with a piece of metadata identifying their first choice in a recent presidential pulse poll:

```
# Boot up a Ruby console on Heroku
$ heroku run console --app dfa-revere
```

```ruby
# Load the application
require './app.rb'

# Set up a MySQL connection
client = Mysql2::Client.new({
  username: ENV['AK_USERNAME'],
  password: ENV["AK_PASSWORD"],
  host: ENV["AK_HOST"],
  database: ENV["AK_DB"]
})

# Get a list of normalized phone numbers & first choice votes
results = client.query("
  SELECT
    x.normalized_phone,
    x.first_choice
  FROM
  (
    SELECT
      m.normalized_phone,
      a.id,
      LEFT(f.value, 31) AS first_choice
    FROM core_page p
    JOIN core_action a ON p.id = a.page_id
    JOIN core_user u ON u.id = a.user_id
    JOIN core_phone m ON u.id = m.user_id
    JOIN core_actionfield f ON a.id = f.parent_id AND f.name = 'candidates_frst_choice'
    WHERE
      p.name IN ('pulse-poll-july-2019')
    ORDER BY m.normalized_phone, a.id DESC
  ) x
  GROUP BY x.normalized_phone
")

# Look up the ID of the metadata field you wish to use, or create a new field if not present:
id = Revere.metadata_field_id("first_choice_2020") || Revere.create_metadata_field("first_choice_2020")

# Sync each first choice vote to Revere
results.each_with_index do |result, i|
  data = { "id" => id, "value" => result['first_choice'] }
  puts Revere.put("/subscriber/addMetadata/#{ result['normalized_phone'] }", body: data.to_json)
end
```

Review the full Revere Mobile API documentation here: https://mobile-developers.reverehq.com