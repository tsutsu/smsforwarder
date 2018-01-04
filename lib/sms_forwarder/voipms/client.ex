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

  # Server (callbacks)

  defstruct api_username: nil, api_password: nil, dids: []

  def init([{api_username, api_password}, account_id]) do
    GenServer.cast(self(), {:query_sms_enabled_dids, account_id})
    {:ok, %__MODULE__{api_username: api_username, api_password: api_password}}
  end

  def handle_cast({:query_sms_enabled_dids, account_id}, state) do
    req_uri = state |> build_request_uri(:getDIDsInfo, account: account_id)
    %{"status" => "success", "dids" => resp_dids} = HTTPoison.get!(req_uri).body |> Poison.decode!

    dids = resp_dids |>
      Enum.filter(fn(r) -> (r["sms_enabled"] == "1") end) |>
      Enum.map(fn(r) -> {account_id, r["did"]} end)

    {:noreply, %{state | dids: dids}}
  end
  def handle_cast(request, state), do: super(request, state)

  def handle_call({:send_sms, dest_did, text}, _from, state) do
    {_source_acct, source_did} = List.first(state.dids)

    send_sms_chunk(text, 0, {source_did, dest_did}, state)

    {:reply, :sending, state}
  end

  def handle_call({:call_endpoint, endpoint_name, args}, _from, state) do
    req_uri = state |> build_request_uri(endpoint_name, args)
    resp = HTTPoison.get!(req_uri).body |> Poison.decode!
    {:reply, resp, state}
  end

  def handle_call(request, from, state), do: super(request, from, state)

  defp send_sms_chunk(msg_chunk, delay, {source_did, dest_did}, state) when byte_size(msg_chunk) <= 160 do
    Task.Supervisor.start_child(SMSForwarder.TaskSupervisor, fn ->
      :timer.sleep(delay)
      req_uri = state |> build_request_uri(:sendSMS, did: source_did, dst: dest_did, message: msg_chunk)
      msg_hash = :crypto.hash(:sha256, msg_chunk) |> Base.encode32(case: :lower, padding: :false) |> String.slice(0..7)
      Logger.debug ["Sending SMS [", msg_hash, "] ", source_did, "->", dest_did, ": ", msg_chunk]
      %{"status" => "success", "sms" => _} = HTTPoison.get!(req_uri, [], [timeout: 30_000, recv_timeout: 30_000]).body |> Poison.decode!
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
