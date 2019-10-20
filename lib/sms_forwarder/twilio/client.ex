require Logger

defmodule SMSForwarder.Twilio.Client do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def send(dest_did, msg_body, attachment_urls \\ []) do
    GenServer.call(__MODULE__, {:send_sms, dest_did, msg_body, attachment_urls})
  end

  # Server (callbacks)

  defstruct dids: []

  def init([]) do
    GenServer.cast(self(), :query_sms_enabled_dids)
    {:ok, %__MODULE__{}}
  end

  def handle_cast(:query_sms_enabled_dids, state) do
    case ExTwilio.IncomingPhoneNumber.all() do
      dids when is_list(dids) ->
        Enum.filter(dids, fn(r) -> (r.capabilities["sms"] && r.capabilities["mms"]) end)
        |> Enum.map(fn(r) -> r.phone_number end)
        {:noreply, %{state | dids: dids}}
      _err ->
        {:noreply, state}
    end
  end
  def handle_cast(_request, state), do: {:noreply, state}

  def handle_call({:send_sms, dest_did, text, atts}, _from, state) do
    source_did = List.first(state.dids)

    send_sms({text, atts}, {source_did, dest_did})

    {:reply, :sending, state}
  end
  def handle_call(_request, _from, state), do: {:noreply, state}

  defp send_sms({msg_body, msg_atts}, {source_did, dest_did}) do
    req = %{
      from: source_did,
      to: e164(dest_did),
      body: msg_body,
    }

    req = case List.first(msg_atts) do
      nil     -> req
      att_uri -> Map.put(req, :media_url, to_string(att_uri))
    end

    resp = ExTwilio.Message.create(req)
    Logger.debug ["Sent SMS: ", inspect(resp)]
  end

  defp e164(did) do
    "+1#{did}"
  end
end
