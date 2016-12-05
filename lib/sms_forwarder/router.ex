defmodule SMSForwarder.Router do
  use Trot.Router

  get "/text" do
    "Thank you for your question."
  end

  import_routes Trot.NotFound
end
