require Logger

defmodule SMSForwarder.VoIPms.Client do
  use GenServer

  @api_base_uri "https://voip.ms/api/v1/rest.php"

  def start_link(api_credentials, account_id) do
    GenServer.start_link(__MODULE__, [api_credentials, account_id], name: __MODULE__)
  end

  def send(dest_did, msg_body) do
    GenServer.call(__MODULE__, {:send_sms, dest_did, msg_body})
  end

  def call(endpoint_name, args) do
    GenServer.call(__MODULE__, {:call_endpoint, endpoint_name, args})
  end

  def lookup_did(from_arg) do
    GenServer.call(__MODULE__, {:lookup_did, from_arg})
  end

  def lookup_nickname(did) do
    GenServer.call(__MODULE__, {:lookup_nickname, did})
  end

  def lookup_channel_name(did) do
    GenServer.call(__MODULE__, {:lookup_channel_name, did})
  end

  # Server (callbacks)

  defstruct [
    api_username: nil,
    api_password: nil,
    own_dids: [],
    nickname_to_did: %{},
    did_to_nickname: %{},
    channel_name_to_did: %{},
    did_to_channel_name: %{}
  ]

  def init([{api_username, api_password}, account_id]) do
    GenServer.cast(self(), {:query_sms_enabled_dids, account_id})
    GenServer.cast(self(), {:retrieve_phonebook, account_id})
    {:ok, %__MODULE__{api_username: api_username, api_password: api_password}}
  end

  def handle_cast({:query_sms_enabled_dids, account_id}, state) do
    req_uri = state |> build_request_uri(:getDIDsInfo, account: account_id)
    %{"status" => "success", "dids" => resp_dids} = HTTPoison.get!(req_uri).body |> Jason.decode!

    own_dids = resp_dids |>
      Enum.filter(fn(r) -> (r["sms_enabled"] == "1") end) |>
      Enum.map(fn(r) -> {account_id, r["did"]} end)

    {:noreply, %{state | own_dids: own_dids}}
  end

  def handle_cast({:retrieve_phonebook, account_id}, state) do
    req_uri = state |> build_request_uri(:getPhonebook, account: account_id)
    %{"status" => "success", "phonebooks" => resp_phonebooks} = HTTPoison.get!(req_uri).body |> Jason.decode!

    did_to_nickname = Map.new(resp_phonebooks, fn(%{"name" => nickname, "number" => did}) -> {did, nickname} end)
    did_to_channel_name = Map.new(did_to_nickname, fn({did, nickname}) -> {did, nickname_to_channel_name(nickname)} end)

    nickname_to_did = Map.new(did_to_nickname, fn({did, nickname}) -> {nickname, did} end)
    channel_name_to_did = Map.new(did_to_channel_name, fn({did, channel_name}) -> {channel_name, did} end)

    {:noreply, %{state |
      did_to_nickname: did_to_nickname,
      nickname_to_did: nickname_to_did,
      did_to_channel_name: did_to_channel_name,
      channel_name_to_did: channel_name_to_did
    }}
  end

  def handle_cast(_request, state), do: {:noreply, state}

  def handle_call({:send_sms, dest_did, text}, _from, state) do
    {_source_acct, source_did} = List.first(state.own_dids)

    send_sms_chunk(text, 0, {source_did, dest_did}, state)

    {:reply, :sending, state}
  end

  def handle_call({:lookup_did, [nickname: nickname]}, _from, %{nickname_to_did: ntd} = state) do
    {:reply, Map.fetch(ntd, nickname), state}
  end
  def handle_call({:lookup_did, [channel_name: channel_name]}, _from, %{channel_name_to_did: chntd} = state) do
    {:reply, Map.fetch(chntd, channel_name), state}
  end

  def handle_call({:lookup_nickname, did}, _from, %{did_to_nickname: dtn} = state) do
    {:reply, Map.fetch(dtn, did), state}
  end
  def handle_call({:lookup_channel_name, did}, _from, %{did_to_channel_name: dtchn} = state) do
    {:reply, Map.fetch(dtchn, did), state}
  end

  def handle_call({:call_endpoint, endpoint_name, args}, _from, state) do
    req_uri = state |> build_request_uri(endpoint_name, args)
    resp = HTTPoison.get!(req_uri).body |> Jason.decode!
    {:reply, resp, state}
  end

  def handle_call(_request, _from, state), do: {:noreply, state}

  defp nickname_to_channel_name(nickname) do
    nickname_camelcased = nickname
    |> String.split(~r/\s+/)
    |> Enum.map(&String.capitalize/1)
    |> Enum.join

    Regex.replace(~r/[^\w+]/, nickname_camelcased, "")
    |> Macro.underscore
  end

  defp send_sms_chunk(msg_chunk, delay, {source_did, dest_did}, state) when byte_size(msg_chunk) <= 160 do
    Task.Supervisor.start_child(SMSForwarder.TaskSupervisor, fn ->
      :timer.sleep(delay)
      req_uri = state |> build_request_uri(:sendSMS, did: source_did, dst: dest_did, message: msg_chunk)
      msg_hash = :crypto.hash(:sha256, msg_chunk) |> Base.encode32(case: :lower, padding: :false) |> String.slice(0..7)
      Logger.debug ["Sending SMS [", msg_hash, "] ", source_did, "->", dest_did, ": ", msg_chunk]
      %{"status" => "success", "sms" => _} = HTTPoison.get!(req_uri, [], [timeout: 30_000, recv_timeout: 30_000]).body |> Jason.decode!
      Logger.debug ["Sent SMS [", msg_hash, "]"]
    end)
  end

  defp build_request_uri(state, method, params) do
    req = %{
      api_username: state.api_username,
      api_password: state.api_password,
      method: to_string(method),
    }
    params = Enum.into(params, %{})
    req = Map.merge(req, params)
    [@api_base_uri, URI.encode_query(req)] |> Enum.join("?")
  end
end
