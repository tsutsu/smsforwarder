defmodule SMSForwarder do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    [voipms_username, voipms_password, voipms_account] = (System.get_env("VOIPMS_CREDENTIALS") || "foo:bar:1") |> String.split(":")
    slack_user_api_token = System.get_env("SLACK_USER_API_TOKEN") || "slack_user"
    slack_bot_api_token = System.get_env("SLACK_BOT_API_TOKEN") || "slack_bot"

    redis_uri = System.get_env("REDIS_URL")

    #sms_did = System.get_env("SMS_DID")

    # Define workers and child supervisors to be supervised
    children = [
      supervisor(Task.Supervisor, [[name: SMSForwarder.TaskSupervisor]])
    ]

    children = children ++ if redis_uri do [
      worker(SMSForwarder.RedisRepo, [redis_uri, [name: SMSForwarder.RedisRepo]]),
      worker(SMSForwarder.AddressBook.Redis, [[name: SMSForwarder.AddressBook]])
    ] else [
      worker(SMSForwarder.AddressBook.InMemory, [[name: SMSForwarder.AddressBook]])
    ] end

    children = children ++ [
      worker(SMSForwarder.Slack.Client, [slack_user_api_token, [name: SMSForwarder.Slack.UserIdentity]], id: SMSForwarder.Slack.UserClient),
      worker(SMSForwarder.Slack.Client, [slack_bot_api_token, [name: SMSForwarder.Slack.BotIdentity]], id: SMSForwarder.Slack.BotClient),
      worker(SMSForwarder.VoIPms.Client, [{voipms_username, voipms_password}, voipms_account]),
      supervisor(SMSForwarder.ConversationSupervisor, [[name: SMSForwarder.ConversationSupervisor]]),
      worker(SMSForwarder.Slack.BotListener, [])
    ]


#    :ets.new

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SMSForwarder.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
