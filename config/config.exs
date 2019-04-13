use Mix.Config

{web_port, ""} = Integer.parse(System.get_env("PORT") || "8000")
web_base_uri = System.get_env("BASE_URI") || "http://localhost:#{web_port}"

config :sms_forwarder, SMSForwarder.HTTP,
  base_uri: web_base_uri,
  port: web_port

config :ex_twilio, account_sid:   {:system, "TWILIO_ACCOUNT_SID"},
                   auth_token:    {:system, "TWILIO_AUTH_TOKEN"}
