defmodule SMSForwarder.Mixfile do
  use Mix.Project

  def project, do: [
    app: :sms_forwarder,
    version: "0.1.1",
    elixir: "~> 1.6",
    build_embedded: Mix.env == :prod,
    start_permanent: Mix.env == :prod,
    deps: deps()
  ]

  def application, do: [
    mod: {SMSForwarder, []},
    extra_applications: [:logger]
  ]

  defp deps, do: [
    {:slack, "~> 0.15.0"},
    {:ex_twilio, "~> 0.7.0"},
    {:httpoison, "~> 1.2", override: true},
    {:trot, "~> 0.7.0"},
    {:calendar, "~> 0.17.4"},
    {:jason, "~> 1.0"},
    {:xml_builder, "~> 2.1"}
  ]
end
