defmodule PhoenixApp0625.GtfsRtTest do
  use ExUnit.Case, async: true

  alias PhoenixApp0625.GtfsRt.GtfsRealtime

  @fixtures_path "test/fixtures/gtfs_rt"

  describe "GTFS-RT protobuf decoding" do
    test "decodes real SNCF trip updates fixture" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      
      binary_data = File.read!(fixture_path)
      
      assert {:ok, feed_message} = decode_feed_message(binary_data)
      assert %GtfsRealtime.FeedMessage{} = feed_message
      assert is_struct(feed_message.header, GtfsRealtime.FeedHeader)
      assert is_list(feed_message.entity)
      assert length(feed_message.entity) > 0
    end

    test "feed header contains valid timestamp and version" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {:ok, feed_message} = decode_feed_message(binary_data)
      header = feed_message.header
      
      assert header.gtfs_realtime_version == "1.0"
      assert is_integer(header.timestamp)
      assert header.timestamp > 0
    end

    test "entities contain trip updates with valid structure" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {:ok, feed_message} = decode_feed_message(binary_data)
      
      trip_update_entities = 
        feed_message.entity
        |> Enum.filter(fn entity -> entity.trip_update != nil end)
      
      assert length(trip_update_entities) > 0
      
      # Test first trip update entity
      entity = List.first(trip_update_entities)
      assert is_binary(entity.id)
      assert entity.id != ""
      
      trip_update = entity.trip_update
      assert is_struct(trip_update, GtfsRealtime.TripUpdate)
      assert is_struct(trip_update.trip, GtfsRealtime.TripDescriptor)
      assert is_binary(trip_update.trip.trip_id)
      assert trip_update.trip.trip_id != ""
    end

    test "trip updates contain stop time updates" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {:ok, feed_message} = decode_feed_message(binary_data)
      
      trip_update_entity = 
        feed_message.entity
        |> Enum.find(fn entity -> 
          entity.trip_update != nil && 
          length(entity.trip_update.stop_time_update) > 0 
        end)
      
      assert trip_update_entity != nil
      
      stop_time_updates = trip_update_entity.trip_update.stop_time_update
      assert is_list(stop_time_updates)
      assert length(stop_time_updates) > 0
      
      # Test first stop time update
      stop_time_update = List.first(stop_time_updates)
      assert is_struct(stop_time_update, GtfsRealtime.TripUpdate.StopTimeUpdate)
      assert is_binary(stop_time_update.stop_id)
      assert stop_time_update.stop_id != ""
    end

    test "vehicle positions contain location data" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {:ok, feed_message} = decode_feed_message(binary_data)
      
      vehicle_entities = 
        feed_message.entity
        |> Enum.filter(fn entity -> entity.vehicle != nil end)
      
      if length(vehicle_entities) > 0 do
        vehicle_entity = List.first(vehicle_entities)
        vehicle = vehicle_entity.vehicle
        
        assert is_struct(vehicle, GtfsRealtime.VehiclePosition)
        assert is_struct(vehicle.trip, GtfsRealtime.TripDescriptor)
        
        if vehicle.position do
          position = vehicle.position
          assert is_struct(position, GtfsRealtime.Position)
          assert is_float(position.latitude)
          assert is_float(position.longitude)
          assert position.latitude >= -90.0 and position.latitude <= 90.0
          assert position.longitude >= -180.0 and position.longitude <= 180.0
        end
      end
    end

    test "handles malformed protobuf data gracefully" do
      malformed_data = <<1, 2, 3, 4, 5>>
      
      assert {:error, :decode_failed} = decode_feed_message(malformed_data)
    end

    test "handles empty data" do
      result = decode_feed_message("")
      # Empty string can decode to empty feed message, which is valid
      case result do
        {:ok, feed_message} ->
          assert %GtfsRealtime.FeedMessage{} = feed_message
          assert feed_message.entity == []
        {:error, :decode_failed} ->
          # This is also acceptable
          assert true
      end
    end

    test "validates GTFS-RT version compatibility" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {:ok, feed_message} = decode_feed_message(binary_data)
      
      # GTFS-RT specification requires version 1.0, 2.0, or compatible
      version = feed_message.header.gtfs_realtime_version
      assert version in ["1.0", "2.0"] or String.starts_with?(version, "1.") or String.starts_with?(version, "2.")
    end
  end

  describe "SNCF-specific GTFS-RT features" do
    test "trip IDs follow SNCF format" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {:ok, feed_message} = decode_feed_message(binary_data)
      
      trip_ids = 
        feed_message.entity
        |> Enum.filter(fn entity -> entity.trip_update != nil end)
        |> Enum.map(fn entity -> entity.trip_update.trip.trip_id end)
        |> Enum.filter(fn trip_id -> trip_id != nil and trip_id != "" end)
      
      assert length(trip_ids) > 0
      
      # Test SNCF trip ID format (typically contains timestamp and identifier)
      sample_trip_id = List.first(trip_ids)
      assert is_binary(sample_trip_id)
      assert String.contains?(sample_trip_id, ":")
      assert String.length(sample_trip_id) > 10
    end

    test "stop IDs follow SNCF format" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {:ok, feed_message} = decode_feed_message(binary_data)
      
      stop_ids = 
        feed_message.entity
        |> Enum.filter(fn entity -> entity.trip_update != nil end)
        |> Enum.flat_map(fn entity -> entity.trip_update.stop_time_update end)
        |> Enum.map(fn stop_time_update -> stop_time_update.stop_id end)
        |> Enum.filter(fn stop_id -> stop_id != nil and stop_id != "" end)
        |> Enum.uniq()
      
      assert length(stop_ids) > 0
      
      # Test SNCF stop ID format (typically starts with "StopPoint:" or "StopArea:")
      sample_stop_id = List.first(stop_ids)
      assert is_binary(sample_stop_id)
      assert String.starts_with?(sample_stop_id, "StopPoint:") or String.starts_with?(sample_stop_id, "StopArea:")
    end

    test "entities have unique IDs" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {:ok, feed_message} = decode_feed_message(binary_data)
      
      entity_ids = 
        feed_message.entity
        |> Enum.map(fn entity -> entity.id end)
        |> Enum.filter(fn id -> id != nil and id != "" end)
      
      unique_ids = Enum.uniq(entity_ids)
      
      assert length(entity_ids) == length(unique_ids), 
        "All entity IDs should be unique"
    end
  end

  describe "performance and memory usage" do
    test "decodes large GTFS-RT feed efficiently" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {time_microseconds, {:ok, feed_message}} = 
        :timer.tc(fn -> decode_feed_message(binary_data) end)
      
      # Should decode within reasonable time (less than 1 second)
      assert time_microseconds < 1_000_000
      
      # Should have reasonable number of entities
      entity_count = length(feed_message.entity)
      assert entity_count > 0
      assert entity_count < 10_000  # Sanity check
    end
  end

  # Helper function to decode feed message with error handling
  defp decode_feed_message(binary_data) do
    try do
      case GtfsRealtime.FeedMessage.decode(binary_data) do
        %GtfsRealtime.FeedMessage{} = feed_message ->
          {:ok, feed_message}
        _ ->
          {:error, :invalid_feed_format}
      end
    rescue
      _error ->
        {:error, :decode_failed}
    end
  end
end