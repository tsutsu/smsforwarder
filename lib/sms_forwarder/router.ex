defmodule SMSForwarder.Router do
  require Logger
  use Trot.Router

  get "/text" do
    "Thank you for your question."
  end

  get "/send" do
    conn = Plug.Conn.fetch_query_params(conn)
    msg = SMSForwarder.Message.new(conn.params)
    SMSForwarder.Bot.received_sms(msg)

    Logger.info ["Received sendSMS req: ", inspect(conn.params)]

    "ok"
  end

  import_routes Trot.NotFound
end
