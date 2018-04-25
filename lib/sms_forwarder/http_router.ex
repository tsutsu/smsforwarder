defmodule SMSForwarder.HTTPRouter do
  require Logger

  use Plug.Builder
  plug Plug.Parsers, parsers: [:urlencoded, :multipart]
  plug Plug.Static, at: "/", from: :trot, only: ~w(attachments)
  use Trot.Router

  get "/send" do
    conn = Plug.Conn.fetch_query_params(conn)
    msg = SMSForwarder.Message.from_voipms(conn.params)
    SMSForwarder.Slack.BotListener.received_sms(msg)

    "ok"
  end

  post "/receive/twilio" do
    Logger.debug ["params: ", inspect(conn.params)]
    msg = SMSForwarder.Message.from_twilio(conn.params)
    SMSForwarder.Slack.BotListener.received_sms(msg)
    {204, ""}
  end

  import_routes Trot.NotFound
end
