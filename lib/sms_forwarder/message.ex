defmodule SMSForwarder.Message do
  defstruct id: nil, from: nil, to: nil, timestamp: nil, body: nil

  def from_twilio(%{"ApiVersion" => "2010-04-01", "From" => msg_from, "To" => msg_to, "MessageSid" => msg_id, "Body" => msg_body}) do
    %__MODULE__{
      id: normalize_twilio_msg_id(msg_id),
      timestamp: Calendar.DateTime.now!("UTC"),
      from: normalize_twilio_phn(msg_from),
      to: normalize_twilio_phn(msg_to),
      body: msg_body
    }
  end

  def from_voipms(%{"date" => msg_ts, "from" => msg_from, "to" => msg_to, "id" => msg_id, "message" => msg_body}) do
    %__MODULE__{
      id: String.to_integer(msg_id),
      timestamp: parse_voipms_ts(msg_ts),
      from: msg_from,
      to: msg_to,
      body: msg_body
    }
  end

  defp normalize_twilio_phn(e164_str) do
    Regex.run(~r/\+1(\d{10})/, e164_str) |> Enum.at(1)
  end

  def normalize_twilio_msg_id(msg_id) do
    Regex.run(~r/SM([0-9a-f]{32})/, msg_id) |> Enum.at(1) |> String.to_integer(16)
  end

  defp parse_twilio_ts(ts) do
    {:ok, dt} = Calendar.DateTime.Parse.rfc2822_utc(ts)
    dt
  end

  defp parse_voipms_ts(ts) do
    [date_str, time_str] = ts |> String.split(" ")
    {{:ok, date}, {:ok, time}} = {Date.from_iso8601(date_str), Time.from_iso8601(time_str)}
    {date, time} = {Date.to_erl(date), Time.to_erl(time)}
    {:ok, dt} = Calendar.DateTime.from_erl({date, time}, "Etc/UTC")
    dt
  end
end
