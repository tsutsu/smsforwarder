defmodule SMSForwarder.Slack.BotListener do
  use Slack
  require Logger

  defstruct in_channels: MapSet.new

  def start_link do
    bot_api_token = Agent.get(SMSForwarder.Slack.BotIdentity, &(&1))
    {:ok, bot_pid} = Slack.Bot.start_link(__MODULE__, %__MODULE__{}, bot_api_token)
    true = Process.register(bot_pid, __MODULE__)
    {:ok, bot_pid}
  end

  def received_sms(sms) do
    send(__MODULE__, {:echo_sms_to_slack, sms})
  end


  def handle_connect(slack, state) do
    channels = SMSForwarder.Slack.Client.using(SMSForwarder.Slack.BotIdentity, fn ->
      Slack.Web.Channels.list["channels"]
      |> Enum.filter(fn(ch) -> ch["is_member"] end)
      |> Enum.map(fn(ch) -> ch["name"] end)
      |> Enum.into(MapSet.new)
    end)

    Logger.info ["Slack bot: listening for events as '", slack.me.name, "' (", slack.me.id, ") on channels: ", inspect(channels)]


    {:ok, %{state | in_channels: channels}}
  end

  def handle_event(_message = %{type: "message", subtype: "bot_message"}, _slack, state), do: {:ok, state}
  def handle_event(message = %{type: "message"}, slack, state) do
    if slack.me.id != message[:user] do
      Logger.debug ["Slack bot: received Slack event\n", inspect(message)]

      channel_name = lookup_channel_name(message.channel, slack)
      if channel_name =~ ~r/^#\d{3}-\d{3}-\d{4}$/ do
        dest_did = channel_name |> String.slice(1..-1) |> String.split("-") |> Enum.join
        SMSForwarder.VoIPms.Client.send(dest_did, message.text)
        :ok
      end
    end

    {:ok, state}
  end
  def handle_event(_, _, state), do: {:ok, state}

  def handle_info({:echo_sms_to_slack, sms}, slack, state) do
    channel_name = [0..2, 3..5, 6..9] |> Enum.map(fn(r) -> String.slice(sms.from, r) end) |> Enum.join("-")

    {state, dest_channel_id} = if Set.member?(state.in_channels, channel_name) do
      {state, lookup_channel_id("##{channel_name}", slack)}
    else
      bot_id = slack.me.id

      new_channel_id = SMSForwarder.Slack.Client.using(SMSForwarder.Slack.UserIdentity, fn ->
        channel_id = Slack.Web.Channels.join(channel_name)["channel"]["id"]
        Slack.Web.Channels.invite(channel_id, bot_id)
        channel_id
      end)

      {%{state | in_channels: Set.put(state.in_channels, channel_name)}, new_channel_id}
    end

    msg_event_opts = case SMSForwarder.AddressBook.get(sms.from) do
      :undefined -> %{as_user: true}
      nickname   -> %{as_user: false, username: nickname}
    end

    msg_attachments = sms.attachments |> Enum.map(fn(att) -> %{
      "fallback" => "#{att[:content_type]} #{att[:uri]}",
      "image_url" => to_string(att[:uri])
    } end)

    msg_event_opts = Map.put(msg_event_opts, :attachments, Poison.encode!(msg_attachments))

    Logger.debug ["posting msg with opts: ", inspect(msg_event_opts)]

    SMSForwarder.Slack.Client.using(SMSForwarder.Slack.BotIdentity, fn ->
      Slack.Web.Chat.post_message(dest_channel_id, sms.body, msg_event_opts)
    end)

    {:ok, state}
  end
  def handle_info(_, _, state), do: {:ok, state}
end
