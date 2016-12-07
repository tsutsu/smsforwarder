defmodule SMSForwarder.RedisRepo do
  def start_link(uri, opts \\ []) do
    client = Exredis.start_using_connection_string(uri)

    if opts[:name] do
      true = Process.register(client, opts[:name])
    end

    {:ok, client}
  end
end
