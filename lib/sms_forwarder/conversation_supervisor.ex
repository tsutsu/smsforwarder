defmodule SMSForwarder.ConversationSupervisor do
  use Supervisor

  def start_link(supervisor_opts \\ []) do
    Supervisor.start_link(__MODULE__, [supervisor_opts])
  end

  def init([opts]) do
    import Supervisor.Spec

    children = [
      worker(SMSForwarder.Conversation, [], restart: :transient)
    ]

    opts = [strategy: :simple_one_for_one] ++ opts
    supervise(children, opts)
  end
end
