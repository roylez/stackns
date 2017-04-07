defmodule Stackns.Nova do
  use GenServer
  use HTTPoison.Base

  defmodule Auth do
    defstruct user: nil, 
      passwd:       nil,
      tenant:       nil,
      auth_url:     nil,
      token:        nil,
      endpoints:    nil,
      token_expiry: nil,
      tenant_id:    nil
  end

  def start_link(auth) do
    GenServer.start_link(__MODULE__, auth, name: __MODULE__)
  end

  def init( auth ) do
    { :ok, struct(Auth, auth) }
  end

  def servers,           do: nova_run(:servers)
  def server(id),        do: nova_run([:servers, id])
  def info,              do: nova_run(:info)
  def server_port(id),   do: nova_run([:servers, id, "os-interface"])
  def nova_run(command), do: GenServer.call(__MODULE__, command)

  def handle_call(:info, _form, auth), do: { :reply, auth, auth }

  def handle_call(msg, from, %{ token: nil } = auth) do
    res = authenticate( auth )
    handle_call(msg, from, res)
  end

  def handle_call(command, from, auth) when is_list(command) do
    cmd = Enum.join(command, "/")
    handle_call(cmd, from, auth)
  end

  def handle_call(command, _from, auth ) do
    auth = authenticate_if_needed(auth)
    { status, resp } = get(auth.endpoints["nova"] <> "/#{command}", [ { "X-Auth-Token", auth.token }])
    res = case { status, resp } do
      { :error, _ } -> { :error, resp }
      { :ok, %{ status_code: 200, body: b } } -> 
        { :ok, b}
      { :ok, %{ body: b } } -> { :error, b }
    end
    {:reply, res, auth }
  end

  def process_response_body( body ) do
    case Poison.decode(body) do
      {:ok, res } -> res
      _ -> body
    end
  end

  def process_request_body(body),      do: Poison.encode!(body)

  def process_request_headers(header), do: header ++ [{"Content-Type", "application/json"}]

  defp authenticate_if_needed(%{ token: nil } = auth), do: authenticate(auth)
  defp authenticate_if_needed(%{ token_expiry: expiry } = auth) do
    if DateTime.compare(expiry, DateTime.utc_now()) == :gt do
      authenticate(auth)
    else
      auth
    end
  end

  defp authenticate( auth ) do
    body  = %{
      "auth" => %{
        "tenantName" => auth.tenant,
        "passwordCredentials" => %{
          "username" => auth.user, 
          "password" => auth.passwd
      }}} 
    { :ok, %{body: body }} = post( auth.auth_url <> "/tokens" , body)
    %{ 
      "access" => %{ 
        "serviceCatalog" => endpoints,
        "token" => %{ 
          "id" => token,
          "expires" => expiry,
          "tenant"  => %{ "id" => tenant_id }
        } 
      }
    } = body
    endpoints = endpoints
                |> Enum.map(& { &1["name"], hd(&1["endpoints"])["publicURL"] } )
                |> Enum.into(%{})
    expiry = expiry |> NaiveDateTime.from_iso8601! |> DateTime.from_naive!("Etc/UTC")
    %{ auth | token: token, tenant_id: tenant_id, endpoints: endpoints, token_expiry: expiry}
  end

end
