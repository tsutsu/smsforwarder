use Mix.Config

config :trot, :port, (System.get_env("PORT") || 8000)
config :trot, :router, SMSForwarder.VoIPms.WebhookRouter
