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

  def handle_event(%{type: "message", subtype: subtype}, _slack, state) when is_binary(subtype), do: {:ok, state}
  def handle_event(%{type: "message", user: "USLACKBOT"}, _slack, state), do: {:ok, state}
  def handle_event(%{type: "message", user: own_id}, %{me: %{id: own_id}}, state), do: {:ok, state}
  def handle_event(%{type: "message"} = message, slack, state) do
    case channel_to_did(message.channel, slack) do
      {:ok, dest_did} ->
        Logger.debug ["Slack listener: received message event\n", inspect(message)]
        Task.Supervisor.start_child(SMSForwarder.TaskSupervisor, fn ->
          received_slack_message(message, dest_did, slack, state)
        end)
        {:ok, state}

      :error -> {:ok, state}
    end
  end
  def handle_event(_, _, state), do: {:ok, state}

  def handle_info({:echo_sms_to_slack, sms}, slack, state) do
    {channel_nicknamed?, channel_name} = case SMSForwarder.VoIPms.Client.lookup_channel_name(sms.from) do
      {:ok, channel_name} -> {true, channel_name}
      :error -> {false, ([0..2, 3..5, 6..9] |> Enum.map(fn(r) -> String.slice(sms.from, r) end) |> Enum.join("-"))}
    end

    {dest_channel_id, state} = if MapSet.member?(state.in_channels, channel_name) do
      {lookup_channel_id("##{channel_name}", slack), state}
    else
      bot_id = slack.me.id

      new_channel_id = SMSForwarder.Slack.Client.using(SMSForwarder.Slack.UserIdentity, fn ->
        channel_id = case Slack.Web.Channels.join(channel_name) do
          %{"channel" => ch} -> Map.fetch!(ch, "id")
          %{"error" => "is_archived"} ->
            archived_channel_id = lookup_channel_id("##{channel_name}", slack)

            Slack.Web.Channels.unarchive(archived_channel_id)
            Slack.Web.Channels.join(channel_name)
            archived_channel_id
        end

        Slack.Web.Channels.invite(channel_id, bot_id)
        channel_id
      end)

      {new_channel_id, %{state | in_channels: MapSet.put(state.in_channels, channel_name)}}
    end

    msg_event_opts = if channel_nicknamed? do
      {:ok, nickname} = SMSForwarder.VoIPms.Client.lookup_nickname(sms.from)
      %{as_user: false, username: nickname}
    else
      %{as_user: true}
    end

    msg_attachments = sms.attachments |> Enum.map(fn(att) -> %{
      "fallback" => "#{att[:content_type]} #{att[:uri]}",
      "image_url" => to_string(att[:uri])
    } end)

    msg_event_opts = Map.put(msg_event_opts, :attachments, Jason.encode!(msg_attachments))

    Logger.debug ["posting msg with opts: ", inspect({sms, channel_name, dest_channel_id, msg_event_opts})]

    SMSForwarder.Slack.Client.using(SMSForwarder.Slack.BotIdentity, fn ->
      resp = Slack.Web.Chat.post_message(dest_channel_id, sms.body, msg_event_opts)
      Logger.debug ["Slack replied: ", inspect(resp)]
    end)

    {:ok, state}
  end
  def handle_info(_, _, state), do: {:ok, state}


  defp channel_to_did("D" <> _id, _slack), do: :error
  defp channel_to_did(channel_id, slack) do
    channel_name = lookup_channel_name(channel_id, slack)

    case Regex.scan(~r/^#(\d{3})-(\d{3})-(\d{4})$/, channel_name, capture: :all_but_first) do
      [did_parts] when is_list(did_parts) -> {:ok, Enum.join(did_parts)}
      [] ->
        case Regex.scan(~r/^#(\w+)$/, channel_name, capture: :all_but_first) do
          [[channel_nickname]] -> SMSForwarder.VoIPms.Client.lookup_did(channel_name: channel_nickname)
          _ -> :error
        end
    end
  end

  defp attachment_path(att_id) do
    Path.join([:code.priv_dir(:trot), "static", "attachments", att_id])
  end

  defp received_slack_upload({"image", _}, message, dest_did, _slack, _state) do
    slack_auth = "Bearer #{System.get_env("SLACK_USER_API_TOKEN")}"
    slack_file = HTTPoison.get!(message[:file][:url_private_download], %{"Authorization" => slack_auth})

    image_hash = :crypto.hash(:sha256, slack_file.body) |> Base.encode32(case: :lower, padding: :false)
    image_newext = message[:file][:mimetype] |> MIME.extensions |> List.first
    image_newname = "#{image_hash}.#{image_newext}"
    image_newpath = attachment_path(image_newname)
    File.mkdir_p!(Path.dirname(image_newpath))
    File.open(image_newpath, [:write], fn(f) ->
      IO.binwrite(f, slack_file.body)
    end)

    image_newuri = Application.get_env(:trot, :base_uri)
    image_newuri = %{image_newuri | path: "/attachments/#{image_newname}"}

    Logger.debug ["New attachment URL: ", to_string(image_newuri)]
    SMSForwarder.Twilio.Client.send(dest_did, message.text, [image_newuri])
  end

  defp received_slack_message(%{subtype: "file_share"} = message, dest_did, slack, state) do
    file_mime = message[:file][:mimetype] |> String.split("/", parts: 2) |> List.to_tuple
    received_slack_upload(file_mime, message, dest_did, slack, state)
  end
  defp received_slack_message(message, dest_did, _slack, _state) do
    SMSForwarder.VoIPms.Client.send(dest_did, message.text)
  end
end
