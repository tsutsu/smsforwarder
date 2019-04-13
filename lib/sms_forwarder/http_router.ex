defmodule SMSForwarder.HTTPRouter do
  require Logger
  use Plug.Router

  plug :match

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason

  plug :dispatch

  plug Plug.Static,
    at: "/attachments",
    from: {:trot, "priv/static/attachments"}

  get "/send" do
    conn = Plug.Conn.fetch_query_params(conn)
    msg = SMSForwarder.Message.from_voipms(conn.params)
    SMSForwarder.Slack.BotListener.received_sms(msg)

    send_resp(conn, 200, "ok")
  end

  post "/receive/twilio" do
    Logger.debug ["params: ", inspect(conn.params)]
    msg = SMSForwarder.Message.from_twilio(conn.params)
    SMSForwarder.Slack.BotListener.received_sms(msg)
    send_resp(conn, 204, "")
  end

  match _ do
    send_resp(conn, 404, "Route not found")
  end
end
