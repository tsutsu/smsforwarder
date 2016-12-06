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
    if message.user != slack.me.id do
      channel_name = lookup_channel_name(message.channel, slack)
      if channel_name =~ ~r/^#\d{3}-\d{3}-\d{4}$/ do
        Logger.info ["Got a message from ", channel_name, ": ", inspect(message.text)]

        Task.Supervisor.start_child(SMSForwarder.TaskSupervisor, fn ->
          dest_did = channel_name |> String.slice(1..-1) |> String.split("-") |> Enum.join
          VoIPms.Client.send(dest_did, message.text)
        end)
      end
    end

    {:ok, state}
  end
  def handle_event(_, _, state), do: {:ok, state}

  def handle_info({:message, msg}, slack, state) do
    channel_name = [0..2, 3..5, 6..9] |> Enum.map(fn(r) -> String.slice(msg.from, r) end) |> Enum.join("-")
    peer_channel = lookup_channel_id("##{channel_name}", slack)

    send_message(msg.body, peer_channel, slack)

    {:ok, state}
  end
  def handle_info(_, _, state), do: {:ok, state}
end
