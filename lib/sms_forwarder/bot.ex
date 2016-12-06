defmodule SMSForwarder.Bot do
  use Slack
  require Logger

  def start_link do
    api_token = System.get_env("SLACK_API_TOKEN")
    {:ok, bot_pid} = Slack.Bot.start_link(__MODULE__, [], api_token)
    true = Process.register(bot_pid, __MODULE__)
    {:ok, bot_pid}
  end

  def received_sms(msg) do
    send(__MODULE__, {:message, msg})
  end


  def handle_connect(slack, state) do
    IO.puts "Connected as #{slack.me.name}"
    {:ok, state}
  end

  def handle_event(message = %{type: "message"}, slack, state) do
    Logger.info ["Got a message: ", inspect(message)]

    {:ok, state}
  end
  def handle_event(_, _, state), do: {:ok, state}

  def handle_info({:message, msg}, slack, state) do

    general_channel = lookup_channel_id("#general", slack)
    msg_str = Poison.encode!(msg)

    send_message(msg_str, general_channel, slack)

    {:ok, state}
  end
  def handle_info(_, _, state), do: {:ok, state}
end
