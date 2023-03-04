defmodule Chat.Server do
  alias Chat.Server.{UDP, TCP, SocketRegister}

  def start() do
    port = Application.fetch_env!(:chat, :port)

    children = [
      SocketRegister,
      {Task.Supervisor, name: Chat.Server.SocketSupervisor, strategy: :one_for_one},
      Supervisor.child_spec({Task, fn -> UDP.open(port) end},
        id: :udp_accepter,
        restart: :permanent
      ),
      Supervisor.child_spec({Task, fn -> TCP.accept(port) end},
        id: :tcp_accepter,
        restart: :permanent
      )
    ]

    opts = [strategy: :one_for_one, name: Server.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
