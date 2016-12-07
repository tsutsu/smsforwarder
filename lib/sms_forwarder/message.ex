defmodule SMSForwarder.Message do
  defstruct id: nil, from: nil, to: nil, timestamp: nil, body: nil

  def from_voipms(%{"date" => msg_ts, "from" => msg_from, "to" => msg_to, "id" => msg_id, "message" => msg_body}) do
    %__MODULE__{
      id: String.to_integer(msg_id),
      timestamp: parse_ts(msg_ts),
      from: msg_from,
      to: msg_to,
      body: msg_body
    }
  end

  defp parse_ts(ts) do
    [date_str, time_str] = ts |> String.split(" ")
    {{:ok, date}, {:ok, time}} = {Date.from_iso8601(date_str), Time.from_iso8601(time_str)}
    {date, time} = {Date.to_erl(date), Time.to_erl(time)}
    {:ok, dt} = Calendar.DateTime.from_erl({date, time}, "Etc/UTC")
    dt
  end
end
