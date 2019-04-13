defmodule SMSForwarder do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    [voipms_username, voipms_password, voipms_account] = (System.get_env("VOIPMS_CREDENTIALS") || "foo:bar:1") |> String.split(":")
    slack_user_api_token = System.get_env("SLACK_USER_API_TOKEN") || "slack_user"
    slack_bot_api_token = System.get_env("SLACK_BOT_API_TOKEN") || "slack_bot"

    #sms_did = System.get_env("SMS_DID")

    # Define workers and child supervisors to be supervised
    children = [
      supervisor(Task.Supervisor, [[name: SMSForwarder.TaskSupervisor]])
    ]

    children = children ++ [
      worker(SMSForwarder.Slack.Client, [slack_user_api_token, [name: SMSForwarder.Slack.UserIdentity]], id: SMSForwarder.Slack.UserClient),
      worker(SMSForwarder.Slack.Client, [slack_bot_api_token, [name: SMSForwarder.Slack.BotIdentity]], id: SMSForwarder.Slack.BotClient),
      worker(SMSForwarder.VoIPms.Client, [{voipms_username, voipms_password}, voipms_account]),
      worker(SMSForwarder.Twilio.Client, []),
      supervisor(SMSForwarder.ConversationSupervisor, [[name: SMSForwarder.ConversationSupervisor]]),
      worker(SMSForwarder.Slack.BotListener, []),
    ]

    children = children ++ [
      Plug.Cowboy.child_spec(scheme: :http, plug: SMSForwarder.HTTPRouter, options: [port: http_port()])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SMSForwarder.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp http_config do
    {:ok, config} = Application.fetch_env(:sms_forwarder, SMSForwarder.HTTP)
    config
  end

  def http_port, do: Keyword.fetch!(http_config(), :port)
  def http_base_uri, do: URI.parse(Keyword.fetch!(http_config(), :base_uri))
end
