use Mix.Config

config :trot, :port, System.get_env("PORT")
config :trot, :router, SMSForwarder.Router
