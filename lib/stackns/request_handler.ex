require Logger

defmodule Stackns.RequestHandler do
  alias Stackns.Hosts
  use GenServer
  @behaviour DNS.Server

  def init( params) do
    { :ok, params }
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

  def handle_call( {:query, req}, _, %{ dns: dns }= state) do
    domain = hd(req.qdlist).domain
    hosts_rec = Hosts.lookup(domain)
    Logger.debug inspect(hosts_rec)
    resp = case hosts_rec do
      [] -> resolve(req, dns)
      _  -> 
        anlist = hosts_rec
                 |> Enum.map(& %DNS.Resource{ domain: domain, class: :in, type: :a, ttl: 0, data: &1})
        Logger.debug inspect anlist
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
end
