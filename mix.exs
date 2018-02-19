defmodule SMSForwarder.Mixfile do
  use Mix.Project

  def project, do: [
    app: :sms_forwarder,
    version: "0.1.0",
    elixir: "~> 1.5",
    build_embedded: Mix.env == :prod,
    start_permanent: Mix.env == :prod,
    deps: deps()
  ]

  def application, do: [
    mod: {SMSForwarder, []},
    extra_applications: [:logger]
  ]

  defp deps, do: [
    {:slack, "~> 0.12.0"},
    {:ex_twilio, "~> 0.5.0"},
    {:httpoison, "~> 1.0", override: true},
    {:trot, "~> 0.6.0"},
    {:calendar, "~> 0.17.4"},
    {:poison, "~> 3.1"},
    {:exredis, "~> 0.2.5"},
    {:xml_builder, "~> 2.1"}
  ]
end
