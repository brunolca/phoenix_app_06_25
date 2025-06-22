defmodule PhoenixApp0625.SncfClientIntegrationTest do
  use PhoenixApp0625.DataCase, async: true

  alias PhoenixApp0625.SncfClient
  alias PhoenixApp0625.GtfsRt.GtfsRealtime
  alias PhoenixApp0625.Trains
  alias PhoenixApp0625.Trains.Train

  @fixtures_path "test/fixtures/gtfs_rt"

  describe "GTFS-RT fixture validation" do
    test "can decode real SNCF protobuf data" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      # Test through the protobuf library directly
      {:ok, feed_message} = 
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
      
      assert %GtfsRealtime.FeedMessage{} = feed_message
      assert is_struct(feed_message.header, GtfsRealtime.FeedHeader)
      assert is_list(feed_message.entity)
      assert length(feed_message.entity) > 0
      
      # Validate header
      assert feed_message.header.gtfs_realtime_version == "1.0"
      assert is_integer(feed_message.header.timestamp)
      assert feed_message.header.timestamp > 0
    end

    test "fixture contains valid SNCF trip updates" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {:ok, feed_message} = 
        case GtfsRealtime.FeedMessage.decode(binary_data) do
          %GtfsRealtime.FeedMessage{} = feed_message -> {:ok, feed_message}
          _ -> {:error, :invalid_feed_format}
        end
      
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
      
      # Check SNCF-specific trip ID format
      assert String.contains?(trip_update.trip.trip_id, ":")
      assert String.length(trip_update.trip.trip_id) > 10
    end

    test "fixture contains valid stop time updates" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {:ok, feed_message} = 
        case GtfsRealtime.FeedMessage.decode(binary_data) do
          %GtfsRealtime.FeedMessage{} = feed_message -> {:ok, feed_message}
          _ -> {:error, :invalid_feed_format}
        end
      
      trip_update_with_stops = 
        feed_message.entity
        |> Enum.find(fn entity -> 
          entity.trip_update != nil && 
          length(entity.trip_update.stop_time_update) > 0 
        end)
      
      if trip_update_with_stops do
        stop_time_updates = trip_update_with_stops.trip_update.stop_time_update
        assert is_list(stop_time_updates)
        assert length(stop_time_updates) > 0
        
        # Test first stop time update
        stop_time_update = List.first(stop_time_updates)
        assert is_struct(stop_time_update, GtfsRealtime.TripUpdate.StopTimeUpdate)
        assert is_binary(stop_time_update.stop_id)
        assert stop_time_update.stop_id != ""
        
        # Check SNCF stop ID format
        assert String.starts_with?(stop_time_update.stop_id, "StopPoint:") or 
               String.starts_with?(stop_time_update.stop_id, "StopArea:")
      end
    end
  end

  describe "data processing performance" do
    test "decodes fixture efficiently" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {time_microseconds, result} = 
        :timer.tc(fn -> 
          GtfsRealtime.FeedMessage.decode(binary_data)
        end)
      
      # Should decode within reasonable time (less than 1 second)
      assert time_microseconds < 1_000_000
      
      # Should return valid feed message
      assert %GtfsRealtime.FeedMessage{} = result
      
      entity_count = length(result.entity)
      assert entity_count > 0
      assert entity_count < 10_000  # Sanity check
    end
  end

  describe "train data extraction and validation" do
    test "can manually extract basic train info from fixture" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {:ok, feed_message} = 
        case GtfsRealtime.FeedMessage.decode(binary_data) do
          %GtfsRealtime.FeedMessage{} = feed_message -> {:ok, feed_message}
          _ -> {:error, :invalid_feed_format}
        end
      
      # Find entity with trip update
      trip_entity = 
        feed_message.entity
        |> Enum.find(fn entity -> 
          entity.trip_update != nil && 
          entity.trip_update.trip != nil &&
          entity.trip_update.trip.trip_id != nil
        end)
      
      if trip_entity do
        # Manual extraction to test data structure
        entity_id = trip_entity.id
        trip_id = trip_entity.trip_update.trip.trip_id
        
        assert is_binary(entity_id)
        assert is_binary(trip_id)
        assert String.length(entity_id) > 0
        assert String.length(trip_id) > 0
        
        # Test SNCF ID formats
        assert String.contains?(trip_id, ":")
        assert String.match?(trip_id, ~r/^[A-Za-z0-9:T_-]+$/)
      end
    end

    test "validates position data when available" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {:ok, feed_message} = 
        case GtfsRealtime.FeedMessage.decode(binary_data) do
          %GtfsRealtime.FeedMessage{} = feed_message -> {:ok, feed_message}
          _ -> {:error, :invalid_feed_format}
        end
      
      vehicle_entity = 
        feed_message.entity
        |> Enum.find(fn entity -> 
          entity.vehicle != nil && 
          entity.vehicle.position != nil
        end)
      
      if vehicle_entity do
        position = vehicle_entity.vehicle.position
        
        assert is_struct(position, GtfsRealtime.Position)
        assert is_float(position.latitude)
        assert is_float(position.longitude)
        
        # Validate coordinates are in valid range
        assert position.latitude >= -90.0 and position.latitude <= 90.0
        assert position.longitude >= -180.0 and position.longitude <= 180.0
        
        # For France, coordinates should be approximately within bounds
        assert position.latitude >= 41.0 and position.latitude <= 51.0
        assert position.longitude >= -6.0 and position.longitude <= 10.0
        
        if position.bearing do
          assert is_float(position.bearing)
          assert position.bearing >= 0.0 and position.bearing < 360.0
        end
      end
    end
  end

  describe "database integration with fixture data" do
    test "can create train records with fixture-like data" do
      # Create a train record with SNCF-like data structure
      train_attrs = %{
        train_number: "OCESN9591F4534896",
        trip_id: "OCESN9591F4534896:2025-06-17T23:52:01Z",
        operator: "SNCF",
        route_short_name: "09:55:00",
        gtfs_trip_id: "OCESN9591F4534896:2025-06-17T23:52:01Z",
        latitude: Decimal.new("48.8566"),
        longitude: Decimal.new("2.3522"),
        bearing: Decimal.new("45.0"),
        timestamp: DateTime.utc_now(),
        is_active: true
      }
      
      {:ok, saved_train} = Trains.upsert_train(train_attrs)
      
      assert %Train{} = saved_train
      assert saved_train.id != nil
      assert saved_train.train_number == train_attrs.train_number
      assert saved_train.trip_id == train_attrs.trip_id
      assert saved_train.operator == train_attrs.operator
      assert saved_train.is_active == true
      
      # Test coordinates
      assert Decimal.equal?(saved_train.latitude, train_attrs.latitude)
      assert Decimal.equal?(saved_train.longitude, train_attrs.longitude)
      assert Decimal.equal?(saved_train.bearing, train_attrs.bearing)
    end

    test "handles SNCF train ID formats correctly" do
      # Test various SNCF train ID formats found in real data
      sncf_train_ids = [
        "OCESN9591F4534896:2025-06-17T23:52:01Z",
        "OCESN9590F4587355:2025-06-20T00:18:59Z",
        "OCESN9246F4502774:2025-06-16T22:25:15Z"
      ]
      
      Enum.each(sncf_train_ids, fn trip_id ->
        train_attrs = %{
          train_number: String.split(trip_id, ":") |> List.first(),
          trip_id: trip_id,
          operator: "SNCF",
          timestamp: DateTime.utc_now(),
          is_active: true
        }
        
        {:ok, saved_train} = Trains.upsert_train(train_attrs)
        
        assert saved_train.trip_id == trip_id
        assert String.length(saved_train.train_number) > 0
        assert saved_train.operator == "SNCF"
      end)
      
      # Verify all trains are saved
      active_trains = Trains.list_active_trains()
      assert length(active_trains) >= length(sncf_train_ids)
    end

    test "upsert works correctly with SNCF data format" do
      trip_id = "OCESN9591F4534896:2025-06-17T23:52:01Z"
      train_number = "OCESN9591F4534896"
      
      initial_attrs = %{
        train_number: train_number,
        trip_id: trip_id,
        operator: "SNCF",
        latitude: Decimal.new("48.8566"),
        longitude: Decimal.new("2.3522"),
        timestamp: DateTime.utc_now(),
        is_active: true
      }
      
      # First insert
      {:ok, train1} = Trains.upsert_train(initial_attrs)
      original_id = train1.id
      
      # Update with new position
      updated_attrs = Map.merge(initial_attrs, %{
        latitude: Decimal.new("48.8600"),
        longitude: Decimal.new("2.3500"),
        bearing: Decimal.new("90.0"),
        timestamp: DateTime.utc_now()
      })
      
      {:ok, train2} = Trains.upsert_train(updated_attrs)
      
      # With :replace_all, it may create a new record rather than update
      # Let's check that the train_number and trip_id combination is still unique
      all_trains = Trains.list_active_trains()
      same_train_trip_combo = Enum.filter(all_trains, fn t -> 
        t.train_number == train_number and t.trip_id == trip_id 
      end)
      
      assert length(same_train_trip_combo) == 1, "Should have exactly one train with this train_number/trip_id combo"
      
      final_train = List.first(same_train_trip_combo)
      
      # Check the final train has the updated values
      assert Decimal.equal?(final_train.latitude, updated_attrs.latitude)
      assert Decimal.equal?(final_train.longitude, updated_attrs.longitude)
      assert Decimal.equal?(final_train.bearing, updated_attrs.bearing)
    end
  end

  describe "SNCF data format validation" do
    test "validates real SNCF stop ID formats from fixture" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {:ok, feed_message} = 
        case GtfsRealtime.FeedMessage.decode(binary_data) do
          %GtfsRealtime.FeedMessage{} = feed_message -> {:ok, feed_message}
          _ -> {:error, :invalid_feed_format}
        end
      
      stop_ids = 
        feed_message.entity
        |> Enum.filter(fn entity -> entity.trip_update != nil end)
        |> Enum.flat_map(fn entity -> entity.trip_update.stop_time_update end)
        |> Enum.map(fn stop_time_update -> stop_time_update.stop_id end)
        |> Enum.filter(fn stop_id -> stop_id != nil and stop_id != "" end)
        |> Enum.uniq()
        |> Enum.take(10)  # Test first 10 unique stop IDs
      
      assert length(stop_ids) > 0
      
      Enum.each(stop_ids, fn stop_id ->
        assert is_binary(stop_id)
        assert String.starts_with?(stop_id, "StopPoint:") or String.starts_with?(stop_id, "StopArea:")
        assert String.contains?(stop_id, "OCE")  # SNCF identifier
        assert String.length(stop_id) > 10
      end)
    end

    test "validates entity ID uniqueness in fixture" do
      fixture_path = Path.join(@fixtures_path, "sncf-all-gtfs-rt-trip-updates")
      binary_data = File.read!(fixture_path)
      
      {:ok, feed_message} = 
        case GtfsRealtime.FeedMessage.decode(binary_data) do
          %GtfsRealtime.FeedMessage{} = feed_message -> {:ok, feed_message}
          _ -> {:error, :invalid_feed_format}
        end
      
      entity_ids = 
        feed_message.entity
        |> Enum.map(fn entity -> entity.id end)
        |> Enum.filter(fn id -> id != nil and id != "" end)
      
      unique_ids = Enum.uniq(entity_ids)
      
      assert length(entity_ids) == length(unique_ids), 
        "All entity IDs should be unique in GTFS-RT feed"
    end
  end
end