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
    rabbit    = rabbit_config(config)
    openstack = openstack_config(config)

    children = [
      worker(Stackns.RequestHandler, [%{dns: dns }]),
      worker(Stackns.RabbitClient, [rabbit]),
      worker(Stackns.Hosts, [openstack]),   # this one starts Nova client as well
      worker(Common.TableManager, [Stackns.Hosts, :hosts ]),
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

  defp rabbit_config(config) do
    %{
      exchange: config["rabbit_exchange"],
      user:     config["rabbit_user"],
      host:     config["rabbit_host"],
      vhost:    config["rabbit_vhost"],
      topic:    config["rabbit_topic"],
      passwd:   config["rabbit_passwd"],
    }
  end

  defp openstack_config(config) do
    %{
      user:     config["os_user"],
      passwd:   config["os_passwd"],
      tenant:   config["os_tenant"],
      auth_url: config["os_auth_url"],
    }
  end

end
