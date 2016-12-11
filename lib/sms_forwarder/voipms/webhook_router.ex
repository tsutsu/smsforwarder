defmodule SMSForwarder.VoIPms.WebhookRouter do
  require Logger

  use Plug.Builder
  plug Plug.Parsers, parsers: [:urlencoded, :multipart]
  use Trot.Router

  get "/contacts" do
    SMSForwarder.AddressBook.dump_all |> Poison.encode!
  end

  get "/contacts/add" do
    conn = Plug.Conn.fetch_query_params(conn)
    SMSForwarder.AddressBook.set(conn.params["did"], conn.params["name"])
    "ok"
  end

  get "/contacts/remove" do
    conn = Plug.Conn.fetch_query_params(conn)
    SMSForwarder.AddressBook.unset(conn.params["did"])
    "ok"
  end

  get "/send" do
    conn = Plug.Conn.fetch_query_params(conn)
    msg = SMSForwarder.Message.from_voipms(conn.params)
    SMSForwarder.Slack.BotListener.received_sms(msg)

    "ok"
  end

  post "/receive/twilio" do
    msg = SMSForwarder.Message.from_twilio(conn.params)
    SMSForwarder.Slack.BotListener.received_sms(msg)
    {204, ""}
  end

  import_routes Trot.NotFound
end
