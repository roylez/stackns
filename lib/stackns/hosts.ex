require Logger

defmodule Stackns.Hosts do
  @moduledoc """
  manages hosts file
  """

  use GenServer
  alias Stackns.Nova

  defmodule State do
    defstruct hosts: nil, nova: nil
  end

  def init(os) do
    { :ok, _ } = Nova.start_link(os)
    Nova.servers()    # to authenticate
    nova = Nova.info()
    { :ok, %State{ nova: nova } }
  end

  def start_link(os) do
    GenServer.start_link(__MODULE__, os, name: __MODULE__)
  end

  def lookup(domain) when is_list(domain), do: lookup(to_string(domain))

  def lookup(domain) do
    GenServer.call(__MODULE__, {:lookup, domain})
  end

  def handle_call({:lookup, domain}, _, %{ hosts: hosts } = state ) do
    resp = hosts
           |> :ets.match({:'_', domain, :'$1'})
           |> List.flatten
    { :reply, resp, state }
  end

  def handle_info( {:"ETS-TRANSFER", tab, _from, _}, state ) do
    load_hosts(tab)
    { :noreply, %{state | hosts: tab}  }
  end

  def handle_cast( {:nova_port_change, %{ "event_type" => "port.create.end" }=payload}, state ) do
    add_nova_port(payload, state)
    { :noreply, state }
  end

  def handle_cast( {:nova_port_change, %{ "event_type" => "port.delete.end" }=payload}, state ) do
    delete_nova_port(payload, state)
    { :noreply, state }
  end

  def handle_cast( {:nova_port_change, _payload}, state ) do
    { :noreply, state }
  end

  def add_nova_port(%{ "payload" => %{ "port" => %{ "tenant_id" => tenant_id}=payload } }, 
      %{ nova: %{ tenant_id: tenant_id }} = state ) do
    %{ 
      "fixed_ips" => [ %{"ip_address" => ip }],
      "device_id" => device_id,
      "id" => port_id 
    } = payload
    {:ok, %{"server" => %{"name" => hostname} }} = Nova.server(device_id)
    save_host_in_ets([hostname, ip, port_id], state.hosts)
  end

  def add_nova_port( _, _ ), do: nil

  def delete_nova_port(%{"_context_tenant_name" => tenant, "payload" => %{"port_id"=> port_id} }, 
      %{ nova: %{ tenant: tenant }} = state ) do
    Logger.info "Deleting port: #{port_id}"
    :ets.delete(state.hosts, port_id)
  end

  def delete_nova_port( _, _) do 
    Logger.warn "here"
  end

  defp load_hosts(tab) do
    hosts = case Nova.servers() do
      { :ok, %{ "servers" => nodes } } ->
        nodes
        |> Stream.map( & [&1["name"], &1["id"]] )
        |> Enum.map( fn([ n, id ]) ->
          { :ok, %{ "interfaceAttachments" => ports } } = Nova.server_port( id )
          ports
          |> Enum.map( & [n, hd(&1["fixed_ips"])["ip_address"], &1["port_id"]])
        end)
        |> Enum.reduce( fn(x, acc) -> acc ++ x end )
      { :error, _reason } -> []
    end
    hosts
    |> Enum.map(& save_host_in_ets(&1, tab) )
  end

  defp save_host_in_ets([host, addr, port_id], tab) do
    Logger.info "Adding [#{port_id}] #{host} : #{addr}"
    ip = Socket.Address.parse(addr)
    :ets.insert( tab, { port_id, host, ip } )
  end
end
