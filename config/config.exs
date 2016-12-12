use Mix.Config

config :trot, :port, (System.get_env("PORT") || 8000)
config :trot, :router, SMSForwarder.VoIPms.WebhookRouter

[twilio_id, twilio_secret] = (System.get_env("TWILIO_CREDENTIALS") || "a:b") |> String.split(":", parts: 2)

config :ex_twilio,
  account_sid: twilio_id,
  auth_token:  twilio_secret
