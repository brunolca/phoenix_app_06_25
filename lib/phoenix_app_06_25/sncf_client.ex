defmodule PhoenixApp0625.SncfClient do
  @moduledoc """
  Client for fetching real-time train data from SNCF GTFS-RT API.
  """

  require Logger
  alias PhoenixApp0625.Trains
  alias PhoenixApp0625.GtfsRt.GtfsRealtime

  @gtfs_rt_trip_updates_url "https://proxy.transport.data.gouv.fr/resource/sncf-all-gtfs-rt-trip-updates"
  @gtfs_rt_alerts_url "https://proxy.transport.data.gouv.fr/resource/sncf-gtfs-rt-service-alerts"

  @doc """
  Fetches and processes real-time train updates.
  """
  def fetch_and_process_updates do
    Logger.info("Fetching SNCF real-time train updates...")

    with {:ok, response} <- Req.get(@gtfs_rt_trip_updates_url),
         {:ok, feed_message} <- decode_gtfs_rt(response.body) do

      processed = process_trip_updates(feed_message.entity)
      Logger.info("Processed #{length(processed)} train updates")

      # Deactivate stale trains
      Trains.deactivate_stale_trains(30)

      {:ok, processed}
    else
      {:error, reason} ->
        Logger.error("Failed to fetch SNCF updates: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp decode_gtfs_rt(binary_data) do
    try do
      case GtfsRealtime.FeedMessage.decode(binary_data) do
        %GtfsRealtime.FeedMessage{} = feed_message ->
          {:ok, feed_message}
        _ ->
          {:error, :invalid_feed_format}
      end
    rescue
      error ->
        Logger.error("Failed to decode GTFS-RT data: #{inspect(error)}")
        {:error, :decode_failed}
    end
  end


  defp process_trip_updates(entities) do
    Enum.map(entities, fn entity ->
      with {:ok, train_data} <- extract_train_data(entity),
           {:ok, train} <- Trains.upsert_train(train_data) do
        # Broadcast update via PubSub
        Phoenix.PubSub.broadcast(
          PhoenixApp0625.PubSub,
          "trains:updates",
          {:train_updated, train}
        )
        {:ok, train}
      else
        {:error, %Ecto.Changeset{} = changeset} ->
          Logger.error("Failed to upsert train: #{inspect(changeset.errors)}")
          {:error, changeset}
        {:error, reason} ->
          Logger.warning("Failed to extract train data: #{inspect(reason)}")
          {:error, reason}
      end
    end)
    |> Enum.filter(fn
      {:ok, _} -> true
      _ -> false
    end)
    |> Enum.map(fn {:ok, train} -> train end)
  end

  defp extract_train_data(%GtfsRealtime.FeedEntity{} = entity) do
    case entity do
      %GtfsRealtime.FeedEntity{
        id: id,
        trip_update: %GtfsRealtime.TripUpdate{} = trip_update
      } ->
        extract_from_trip_update(id, trip_update)

      %GtfsRealtime.FeedEntity{
        id: id,
        vehicle: %GtfsRealtime.VehiclePosition{} = vehicle_position
      } ->
        extract_from_vehicle_position(id, vehicle_position)

      _ ->
        {:error, :unsupported_entity_type}
    end
  end

  defp extract_from_trip_update(entity_id, trip_update) do
    %GtfsRealtime.TripUpdate{
      trip: trip,
      vehicle: vehicle,
      timestamp: timestamp,
      delay: delay
    } = trip_update

    with {:ok, position_data} <- extract_position_from_trip_update(trip_update),
         {:ok, basic_data} <- extract_basic_train_data(entity_id, trip, vehicle, timestamp, delay) do
      {:ok, Map.merge(basic_data, position_data)}
    else
      error -> error
    end
  end

  defp extract_from_vehicle_position(entity_id, vehicle_position) do
    %GtfsRealtime.VehiclePosition{
      trip: trip,
      vehicle: vehicle,
      position: position,
      timestamp: timestamp
    } = vehicle_position

    with {:ok, position_data} <- extract_position_data(position),
         {:ok, basic_data} <- extract_basic_train_data(entity_id, trip, vehicle, timestamp, nil) do
      {:ok, Map.merge(basic_data, position_data)}
    else
      error -> error
    end
  end

  defp extract_position_from_trip_update(%GtfsRealtime.TripUpdate{vehicle: nil}), do: {:ok, %{}}
  defp extract_position_from_trip_update(%GtfsRealtime.TripUpdate{vehicle: _vehicle}) do
    # For trip updates, position might not be directly available
    # Return empty position data - this will be filled by vehicle position updates
    {:ok, %{}}
  end

  defp extract_position_data(nil), do: {:ok, %{}}
  defp extract_position_data(%GtfsRealtime.Position{} = position) do
    %GtfsRealtime.Position{
      latitude: lat,
      longitude: lon,
      bearing: bearing,
      speed: speed
    } = position

    {:ok, %{
      latitude: Decimal.new(to_string(lat)),
      longitude: Decimal.new(to_string(lon)),
      bearing: bearing && Decimal.new(to_string(bearing)),
      speed_kmh: speed && Decimal.new(to_string(speed))
    }}
  end

  defp extract_basic_train_data(entity_id, trip, vehicle, timestamp, delay) do
    train_number = extract_train_number(entity_id)
    operator = extract_operator(train_number)

    trip_id = trip && trip.trip_id
    route_id = trip && trip.route_id
    vehicle_id = vehicle && vehicle.id

    timestamp_datetime = if timestamp do
      DateTime.from_unix!(timestamp)
    else
      DateTime.utc_now()
    end

    {:ok, %{
      train_number: train_number,
      operator: operator,
      trip_id: trip_id,
      route_short_name: route_id,
      delay_seconds: delay || 0,
      vehicle_id: vehicle_id,
      gtfs_trip_id: trip_id,
      timestamp: timestamp_datetime,
      is_active: true
    }}
  end

  defp extract_train_number(entity_id) do
    case String.split(entity_id, "_") do
      [type, number | _] -> "#{type} #{number}"
      _ -> entity_id
    end
  end

  defp extract_operator(train_number) do
    cond do
      String.starts_with?(train_number, "TGV") -> "SNCF Voyageurs"
      String.starts_with?(train_number, "TER") -> "SNCF Voyageurs"
      String.starts_with?(train_number, "IC") -> "SNCF Voyageurs"
      true -> "SNCF"
    end
  end
end
