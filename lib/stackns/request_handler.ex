require Logger

defmodule Stackns.RequestHandler do
  use GenServer
  @behaviour DNS.Server

  def init( params) do
    { :ok, params |> Map.put_new(:hosts, nil) }
  end

  def start_link(state) do
    GenServer.start_link(__MODULE__, state, name: __MODULE__)
  end

  def handle(record, {_ip, _}) do
    Logger.debug inspect(record)
    query( record )
  end

  def query( req ) do
    GenServer.call(__MODULE__, {:query, req })
  end

  def handle_call( {:query, req}, _, %{ dns: dns, hosts: hosts } = state) do
    domain = hd(req.qdlist).domain
    resp = case :ets.lookup(hosts, domain) do
      []        -> resolve(req, dns)
      addresses -> 
        anlist = addresses 
                 |> Keyword.values
                 |> Enum.map(& %DNS.Resource{ domain: domain, class: :in, type: :a, ttl: 0, data: &1})
        %{req | anlist: anlist}
    end
    { :reply, resp, state }
  end

  def resolve(req, dns) do
    client = Socket.UDP.open!
    Socket.Datagram.send!(client, DNS.Record.encode(req), dns)
    { data, _server } = Socket.Datagram.recv!(client)
    DNS.Record.decode(data)
  end

  def handle_info( {:"ETS-TRANSFER", tab, _from, _}, state ) do
    { :noreply, %{state | hosts: tab}  }
  end
end
