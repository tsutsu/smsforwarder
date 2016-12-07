defmodule SMSForwarder.Mixfile do
  use Mix.Project

  def project do
    [app: :sms_forwarder,
     version: "0.1.0",
     elixir: "~> 1.3",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :slack, :trot, :calendar, :httpoison, :exredis],
     mod: {SMSForwarder, []}]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do [
    {:slack, "~> 0.9.0"},
    {:httpoison, "~> 0.9.0"},
    {:trot, github: "tsutsu/trot"},
    {:calendar, "~> 0.16.1"},
    {:poison, "~> 3.0"},
    {:exredis, "~> 0.2.5"}
  ] end
end
