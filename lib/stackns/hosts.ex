require Logger

defmodule Stackns.Hosts do
  @moduledoc """
  manages hosts file
  """

  @hosts_file Application.get_env(:stackns, :hosts_file)

  use GenServer

  def init(_) do
    { :ok, %{ hosts: nil } }
  end

  def start_link do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def lookup(domain) when is_list(domain), do: lookup(to_string(domain))

  def lookup(domain) do
    GenServer.call(__MODULE__, {:lookup, domain})
  end

  def handle_call({:lookup, domain}, _, %{ hosts: hosts } = state ) do
    resp = :ets.lookup(hosts, domain)
    { :reply, resp, state }
  end

  def handle_info( {:"ETS-TRANSFER", tab, _from, _}, state ) do
    load_hosts(tab)
    { :noreply, %{state | hosts: tab}  }
  end

  defp load_hosts(tab) do
    if File.exists?( @hosts_file ) do
      @hosts_file
      |> File.stream!([:read])
      |> process_hosts_lines
      |> Enum.map(& save_host_in_ets(&1, tab))
    end
  end

  defp process_hosts_lines(stream) do
    stream
    |> Stream.map( &String.trim_leading/1 )
    |> Stream.filter( & not String.starts_with?(&1, "#") )
    |> Stream.map( &(Regex.replace(~r/\s+(#.*)?$/, &1, "") ) )
    |> Enum.map( &String.split/1 )
  end

  defp save_host_in_ets([host, addr], tab) do
    Logger.debug "Loading #{host} : #{addr}"
    ip = Socket.Address.parse(addr)
    :ets.insert( tab, { host, ip } )
  end
end
