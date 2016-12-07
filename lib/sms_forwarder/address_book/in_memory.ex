defmodule SMSForwarder.AddressBook.InMemory do
  use GenServer

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  # Server (callbacks)

  def init(_) do
    {:ok, %{}}
  end

  def handle_call({:set, did, name}, _from, m) do
    m = Map.put(m, did, name)
    {:reply, :ok, m}
  end

  def handle_call({:unset, did}, _from, m) do
    m = Map.delete(m, did)
    {:reply, :ok, m}
  end

  def handle_call({:get, did}, _from, m) do
    v = Map.get(m, did)
    {:reply, v, m}
  end

  def handle_call(:dump_all, _from, m) do
    {:reply, m, m}
  end

  def handle_call(request, from, state), do: super(request, from, state)
end
