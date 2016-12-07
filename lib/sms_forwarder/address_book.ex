defmodule SMSForwarder.AddressBook do
  def set(did, display_name) do
    GenServer.call(__MODULE__, {:set, did, display_name})
  end

  def unset(did) do
    GenServer.call(__MODULE__, {:unset, did})
  end

  def get(did) do
    GenServer.call(__MODULE__, {:get, did})
  end

  def dump_all do
    GenServer.call(__MODULE__, :dump_all)
  end
end
