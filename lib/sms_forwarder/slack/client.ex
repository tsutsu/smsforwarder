require Logger

defmodule SMSForwarder.Slack.Client do
  def start_link(api_token, opts \\ []) do
    Agent.start_link(fn -> api_token end, opts)
  end

  def using(agent, fun) do
    Agent.get agent, fn(new_tok) ->
      prev_tok = Application.get_env(:slack, :api_token)
      Application.put_env(:slack, :api_token, new_tok)
      val = fun.()
      Application.put_env(:slack, :api_token, prev_tok)
      val
    end
  end
end
