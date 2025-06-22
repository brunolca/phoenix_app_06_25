defmodule PhoenixApp0625Web.TrainMapLive do
  use PhoenixApp0625Web, :live_view
  alias PhoenixApp0625.Trains

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PhoenixApp0625.PubSub, "trains:updates")
    end

    trains = Trains.list_active_trains()

    {:ok,
     socket
     |> stream(:trains, trains)
     |> assign(:selected_train, nil)
     |> assign(:total_trains, length(trains))}
  end

  @impl true
  def handle_info({:train_updated, train}, socket) do
    # Check if train exists in stream before updating count
    is_new_train = !Map.has_key?(socket.assigns.streams.trains, train.id)

    socket = stream_insert(socket, :trains, train)

    socket = if is_new_train do
      update(socket, :total_trains, &(&1 + 1))
    else
      socket
    end

    {:noreply, socket}
  end

  @impl true
  def handle_event("train-clicked", %{"train_id" => train_id}, socket) do
    # Find train from stream by ID
    train_id = String.to_integer(train_id)
    train = Map.get(socket.assigns.streams.trains, train_id)
    {:noreply, assign(socket, :selected_train, train)}
  end

  @impl true
  def handle_event("close-popup", _params, socket) do
    {:noreply, assign(socket, :selected_train, nil)}
  end


  defp serialize_train(train) do
    %{
      id: train.id,
      train_number: train.train_number,
      operator: train.operator,
      latitude: train.latitude && Decimal.to_float(train.latitude),
      longitude: train.longitude && Decimal.to_float(train.longitude),
      bearing: train.bearing && Decimal.to_float(train.bearing),
      speed_kmh: train.speed_kmh && Decimal.to_float(train.speed_kmh),
      delay_seconds: train.delay_seconds,
      route_short_name: train.route_short_name
    }
  end

  defp format_delay(nil), do: "On time"
  defp format_delay(0), do: "On time"
  defp format_delay(seconds) when seconds > 0, do: "+#{div(seconds, 60)}min"
  defp format_delay(seconds) when seconds < 0, do: "#{div(seconds, 60)}min"

  defp train_color(train_number) do
    cond do
      String.starts_with?(train_number, "TGV") -> "#e74c3c"
      String.starts_with?(train_number, "TER") -> "#3498db"
      String.starts_with?(train_number, "IC") -> "#f39c12"
      true -> "#95a5a6"
    end
  end

end
