defmodule SMSForwarder.AddressBook.Redis do
  use GenServer
  import Exredis.Api

  @store_key "contacts"

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  # Server (callbacks)

  def init(_) do
    {:ok, nil}
  end

  def handle_call({:set, did, name}, _from, state) do
    SMSForwarder.RedisRepo |> hset(@store_key, did, name)
    {:reply, :ok, state}
  end

  def handle_call({:unset, did}, _from, state) do
    SMSForwarder.RedisRepo |> hdel(@store_key, did)
    {:reply, :ok, state}
  end

  def handle_call({:get, did}, _from, state) do
    v = SMSForwarder.RedisRepo |> hget(@store_key, did)
    {:reply, v, state}
  end

  def handle_call(:dump_all, _from, state) do
    v = SMSForwarder.RedisRepo |> hgetall(@store_key)
    {:reply, v, state}
  end

  def handle_call(request, from, state), do: super(request, from, state)
end
