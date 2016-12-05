use Mix.Config

config :trot, :port, {:system, "PORT"}
config :trot, :router, SMSForwarder.Router
