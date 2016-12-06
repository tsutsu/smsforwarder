defmodule VoIPms.Client do
  use GenServer

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def send(dest_did, text) do
    GenServer.call(__MODULE__, {:send_sms, dest_did, text}, 90_000)
  end

  # Server (callbacks)

  defstruct api_username: nil, api_password: nil, did: nil

  def init(_args) do
    [username, password] = System.get_env("VOIPMS_CREDENTIALS") |> String.split(":")
    did = System.get_env("VOIPMS_DID")
    {:ok, %__MODULE__{api_username: username, api_password: password, did: did}}
  end

  def handle_call({:send_sms, dest_did, msg_body}, _from, state) do
    req = %{
      api_username: state.api_username,
      api_password: state.api_password,
      method: "sendSMS",
      did: state.did,
      dst: dest_did,
      message: msg_body
    }
    req_uri = ["https://voip.ms/api/v1/rest.php", URI.encode_query(req)] |> Enum.join("?")
    resp = HTTPoison.get!(req_uri, [], [timeout: 30_000, recv_timeout: 30_000]).body |> Poison.decode!
    {:reply, {:sent, resp["sms"]}, state}
  end
  def handle_call(request, from, state), do: super(request, from, state)
end
