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
      channel_name = lookup_channel_name(message.channel, slack)
      if channel_name =~ ~r/^#\d{3}-\d{3}-\d{4}$/ do
        dest_did = channel_name |> String.slice(1..-1) |> String.split("-") |> Enum.join
        Logger.debug ["Slack listener: received message event\n", inspect(message)]
        Task.Supervisor.start_child(SMSForwarder.TaskSupervisor, fn ->
          received_slack_message(message, dest_did, slack, state)
        end)
      end
    end

    {:ok, state}
  end
  def handle_event(_, _, state), do: {:ok, state}

  def handle_info({:echo_sms_to_slack, sms}, slack, state) do
    channel_name = [0..2, 3..5, 6..9] |> Enum.map(fn(r) -> String.slice(sms.from, r) end) |> Enum.join("-")

    {state, dest_channel_id} = if MapSet.member?(state.in_channels, channel_name) do
      {state, lookup_channel_id("##{channel_name}", slack)}
    else
      bot_id = slack.me.id

      new_channel_id = SMSForwarder.Slack.Client.using(SMSForwarder.Slack.UserIdentity, fn ->
        channel_id = Slack.Web.Channels.join(channel_name)["channel"]["id"]
        Slack.Web.Channels.invite(channel_id, bot_id)
        channel_id
      end)

      {%{state | in_channels: MapSet.put(state.in_channels, channel_name)}, new_channel_id}
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
