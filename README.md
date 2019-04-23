This application acts as an endpoint to subscribe mobile phone numbers to Revere Mobile & sync accompanying metadata.

Example use:

```
curl -X POST localhost:4567/mobile_flow_id --data '{"phone": "(802) 555-0188", "metadata": {"Favorite vegetable": "Rutabaga"}}'
```

(Replace the mobile_flow_id slug of the URL with the 24-character hexadecimal ID of the Revere mobile flow you wish to trigger.)

If running locally, make a copy of the `.env.example` file, rename it to `.env`, and set the `REVERE_API_KEY` environment variable. If running on Heroku, use the built-in interface to set a `REVERE_API_KEY` environment variable.