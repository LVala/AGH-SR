defmodule Chat.Client do
  @udp_data """

                ;'-.
    `;-._        )  '---.._
      >  `-.__.-'          `'.__
     /_.-'-._         _,   ^ ---)
     `       `'------/_.'----```
  """

  @mc_udp_data """

                    ,,__
        ..  ..   / o._)
       /--'/--\  \-'||
      /        \_/ / |
    .'\  \__\  __.'.'
      )\ |  )\ |
     // \\ // \\
    ||_  \\|_  \\_
    '--' '--'' '--'
  """

  def start() do
    address = Application.fetch_env!(:chat, :address)
    port = Application.fetch_env!(:chat, :port)
    multicast_address = Application.fetch_env!(:chat, :multicast_address)
    multicast_port = Application.fetch_env!(:chat, :multicast_port)

    open(address, port, multicast_address, multicast_port)
  end

  defp open(address, port, mc_address, mc_port) do
    IO.puts("Chat client\nPress Ctrl-C to leave\n--------")

    with {:ok, tcp_socket} <-
           :gen_tcp.connect(address, port, [
             :binary,
             packet: :line,
             active: false,
             reuseaddr: true
           ]),
         {:ok, {_address, local_port}} <- :inet.sockname(tcp_socket),
         {:ok, udp_socket} <-
           :gen_udp.open(local_port, [:binary, active: false, reuseaddr: true]),
         :ok <- :gen_udp.connect(udp_socket, address, port),
         {:ok, udp_mc_socket} <-
           :gen_udp.open(mc_port, [
             :binary,
             active: false,
             reuseaddr: true,
             ip: mc_address,
             add_membership: {mc_address, {0, 0, 0, 0}}
           ]) do
      Task.start_link(fn -> loop_tcp_receiver(tcp_socket) end)
      Task.start_link(fn -> loop_udp_receiver(udp_socket) end)
      Task.start_link(fn -> loop_udp_receiver(udp_mc_socket) end)

      loop_sender({tcp_socket, udp_socket, udp_mc_socket}, {mc_address, mc_port}, true)
    else
      {:error, reason} ->
        IO.puts("Connection failed, reason: #{reason}")
        Process.exit(self(), :kill)
    end
  end

  defp loop_sender({tcp_socket, udp_socket, udp_mc_socket} = sockets, addr, get_name?) do
    prompt = if get_name?, do: "Name: ", else: ">>> "
    data = IO.gets(prompt)

    case data do
      # dont send empty strings
      "\n" ->
        loop_sender(sockets, addr, get_name?)

      "U\n" when not get_name? ->
        case :gen_udp.send(udp_socket, @udp_data) do
          :ok ->
            loop_sender(sockets, addr, get_name?)

          {:error, reason} ->
            IO.puts("Failed to send UDP data, reason: #{reason}")
            Process.exit(self(), :kill)
        end

      "M\n" when not get_name? ->
        case :gen_udp.send(udp_mc_socket, addr, @mc_udp_data) do
          :ok ->
            loop_sender(sockets, addr, get_name?)

          {:error, reason} ->
            IO.puts("Failed to send UDP data to multicast address, reason #{reason}")
            Process.exit(self(), :kill)
        end

      _other ->
        case :gen_tcp.send(tcp_socket, data) do
          :ok ->
            loop_sender(sockets, addr, false)

          {:error, reason} ->
            IO.puts("Connection terminated, reason: #{reason}")
            Process.exit(self(), :kill)
        end
    end
  end

  defp loop_tcp_receiver(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        IO.write(data)
        loop_tcp_receiver(socket)

      {:error, reason} ->
        IO.puts("TCP connection terminated, reason: #{reason}")
        Process.exit(self(), :kill)
    end
  end

  defp loop_udp_receiver(socket) do
    case :gen_udp.recv(socket, 0) do
      {:ok, {_address, _port, data}} ->
        IO.write(data)
        loop_udp_receiver(socket)

      {:error, reason} ->
        IO.puts("UDP datagram could not be received, reason: #{reason}")
        Process.exit(self(), :kill)
    end
  end
end
