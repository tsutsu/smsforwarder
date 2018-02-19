use Mix.Config

web_port = System.get_env("PORT") || 8000
web_base_uri = System.get_env("BASE_URI") || "http://localhost:#{web_port}"

config :trot, :base_uri, URI.parse(web_base_uri)
config :trot, :port, web_port
config :trot, :router, SMSForwarder.HTTPRouter

config :ex_twilio, account_sid:   {:system, "TWILIO_ACCOUNT_SID"},
                   auth_token:    {:system, "TWILIO_AUTH_TOKEN"}
