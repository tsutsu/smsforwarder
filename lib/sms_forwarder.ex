defmodule SMSForwarder do
  use Application

  # See http://elixir-lang.org/docs/stable/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    # Define workers and child supervisors to be supervised
    children = [
      supervisor(Task.Supervisor, [[name: SMSForwarder.TaskSupervisor]]),
      worker(SMSForwarder.Bot, []),
      worker(VoIPms.Client, [])
    ]

    # See http://elixir-lang.org/docs/stable/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: SMSForwarder.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
