use Mix.Config

web_port = System.get_env("PORT") || 8000
web_base_uri = System.get_env("BASE_URI") || "http://localhost:#{web_port}"

config :trot, :base_uri, URI.parse(web_base_uri)
config :trot, :port, web_port
config :trot, :router, SMSForwarder.HTTPRouter

twilio_creds = System.get_env("TWILIO_CREDENTIALS") || "a:b"
[twilio_id, twilio_secret] = twilio_creds |> String.split(":", parts: 2)

config :ex_twilio,
  account_sid: twilio_id,
  auth_token:  twilio_secret
