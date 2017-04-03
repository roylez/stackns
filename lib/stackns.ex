require Logger

defmodule Stackns do
  @moduledoc """
  A minimal DNS server for openstack client environment

  Configurable options:

  * listening_port: Listening port, default to 53
  * dns: Upstream DNS, default to 8.8.8.8
  * dns_port: Upstream DNS port, default to 53
  """

  use Application
  import Supervisor.Spec

  def start(_type, _args) do
    config = load_config()
    dns = { 
      Map.get(config, "dns_address", "8.8.8.8"), 
      Map.get(config, "dns_port", 53)
    }
    listening_port = Map.get(config, "listening_port", 53)

    children = [
      worker(Stackns.RequestHandler, [%{dns: dns }]),
      worker(Stackns.Hosts, []),
      worker(Common.TableManager, [Stackns.Hosts, :hosts, [:duplicate_bag] ]),
      worker(Task, [DNS.Server, :accept, [listening_port, Stackns.RequestHandler]]),
    ]

    opts = [strategy: :one_for_one, name: __MODULE__ ]

    Supervisor.start_link(children, opts)
  end

  defp load_config do
    config = YamlElixir.read_from_file Application.get_env(:stackns, :config_file)
    Logger.info "Configuration loaded: #{inspect(config)}"
    config
  end

end
