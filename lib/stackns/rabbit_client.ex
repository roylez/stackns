require Logger

defmodule Stackns.RabbitClient do
  use GenServer 
  use AMQP

  @queue    Socket.Host.name() |> to_string()

  def start_link(rabbit) do
    GenServer.start_link(__MODULE__, rabbit, name: __MODULE__)
  end

  def init(%{ exchange: exchange, user: user, passwd: passwd, host: host, vhost: vhost, topic: topic }) do
    {:ok, conn} = Connection.open("amqp://#{user}:#{passwd}@#{host}/#{vhost}")
    {:ok, chan} = Channel.open(conn)
    Exchange.declare(chan, exchange, :topic, durable: false)
    Queue.declare(chan, @queue, durable: false, auto_delete: false)
    Queue.bind(chan, @queue, exchange, routing_key: topic)
    # Register the GenServer process as a consumer
    {:ok, _consumer_tag} = Basic.consume(chan, @queue)
    {:ok, chan}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, %{consumer_tag: _consumer_tag}}, chan) do
    {:stop, :normal, chan}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, %{consumer_tag: _consumer_tag}}, chan) do
    {:noreply, chan}
  end

  def handle_info({:basic_deliver, payload, %{delivery_tag: tag, redelivered: _redelivered}}, chan) do
    payload 
    |> Poison.decode!
    |> consume(chan, tag)
    {:noreply, chan}
  end

  defp consume(payload, chan, tag) do
    GenServer.cast(Stackns.Hosts, {:nova_port_change, payload})
    Basic.ack chan, tag
  end
end
