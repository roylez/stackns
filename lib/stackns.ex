require Logger

defmodule Stackns do
  @moduledoc """
  A minimal DNS server for openstack client environment

  Configurable options:

  * port: Listening port, default to 53
  * dns: Upstream DNS, default to use system DNS
  * dns_port: Upstream DNS port, default to 53
  """

  use Application
  import Supervisor.Spec

  def start(_type, _args) do
    children = [
      worker(Stackns.RequestHandler, [%{dns: { "8.8.8.8", 53} }]),
      worker(Common.TableManager, [Stackns.RequestHandler, :hosts ]),
      worker(Task, [DNS.Server, :accept, [5300, Stackns.RequestHandler]]),
    ]

    opts = [strategy: :one_for_one, name: __MODULE__ ]

    Supervisor.start_link(children, opts)
  end

end
