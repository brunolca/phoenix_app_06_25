defmodule PhoenixApp0625.GtfsRt.GtfsRealtime do
  @moduledoc """
  GTFS Realtime protobuf definitions for decoding transit data feeds.
  """
  
  defmodule StopTimeEvent do
    use Protobuf, syntax: :proto2

    field :delay, 1, optional: true, type: :int32
    field :time, 2, optional: true, type: :int64
    field :uncertainty, 3, optional: true, type: :int32
  end

  defmodule Position do
    use Protobuf, syntax: :proto2

    field :latitude, 1, required: true, type: :float
    field :longitude, 2, required: true, type: :float
    field :bearing, 3, optional: true, type: :float
    field :odometer, 4, optional: true, type: :double
    field :speed, 5, optional: true, type: :float
  end

  defmodule VehicleDescriptor do
    use Protobuf, syntax: :proto2

    field :id, 1, optional: true, type: :string
    field :label, 2, optional: true, type: :string
    field :license_plate, 3, optional: true, type: :string
  end

  defmodule TripDescriptor do
    use Protobuf, syntax: :proto2

    defmodule ScheduleRelationship do
      use Protobuf, enum: true, syntax: :proto2
      field :SCHEDULED, 0
      field :ADDED, 1
      field :UNSCHEDULED, 2
      field :CANCELED, 3
    end

    field :trip_id, 1, optional: true, type: :string
    field :route_id, 5, optional: true, type: :string
    field :direction_id, 6, optional: true, type: :uint32
    field :start_time, 2, optional: true, type: :string
    field :start_date, 3, optional: true, type: :string
    field :schedule_relationship, 4, optional: true, type: __MODULE__.ScheduleRelationship, enum: true
  end

  defmodule TripUpdate do
    use Protobuf, syntax: :proto2

    defmodule StopTimeUpdate do
      use Protobuf, syntax: :proto2

      defmodule ScheduleRelationship do
        use Protobuf, enum: true, syntax: :proto2
        field :SCHEDULED, 0
        field :SKIPPED, 1
        field :NO_DATA, 2
      end

      field :stop_sequence, 1, optional: true, type: :uint32
      field :stop_id, 4, optional: true, type: :string
      field :arrival, 2, optional: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.StopTimeEvent
      field :departure, 3, optional: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.StopTimeEvent
      field :schedule_relationship, 5, optional: true, type: __MODULE__.ScheduleRelationship, enum: true, default: 0
    end

    field :trip, 1, required: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.TripDescriptor
    field :vehicle, 3, optional: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.VehicleDescriptor
    field :stop_time_update, 2, repeated: true, type: __MODULE__.StopTimeUpdate
    field :timestamp, 4, optional: true, type: :uint64
    field :delay, 5, optional: true, type: :int32
  end

  defmodule VehiclePosition do
    use Protobuf, syntax: :proto2

    defmodule VehicleStopStatus do
      use Protobuf, enum: true, syntax: :proto2
      field :INCOMING_AT, 0
      field :STOPPED_AT, 1
      field :IN_TRANSIT_TO, 2
    end

    defmodule CongestionLevel do
      use Protobuf, enum: true, syntax: :proto2
      field :UNKNOWN_CONGESTION_LEVEL, 0
      field :RUNNING_SMOOTHLY, 1
      field :STOP_AND_GO, 2
      field :CONGESTION, 3
      field :SEVERE_CONGESTION, 4
    end

    defmodule OccupancyStatus do
      use Protobuf, enum: true, syntax: :proto2
      field :EMPTY, 0
      field :MANY_SEATS_AVAILABLE, 1
      field :FEW_SEATS_AVAILABLE, 2
      field :STANDING_ROOM_ONLY, 3
      field :CRUSHED_STANDING_ROOM_ONLY, 4
      field :FULL, 5
      field :NOT_ACCEPTING_PASSENGERS, 6
    end

    field :trip, 1, optional: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.TripDescriptor
    field :vehicle, 8, optional: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.VehicleDescriptor
    field :position, 2, optional: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.Position
    field :current_stop_sequence, 3, optional: true, type: :uint32
    field :stop_id, 7, optional: true, type: :string
    field :current_status, 4, optional: true, type: __MODULE__.VehicleStopStatus, enum: true, default: 2
    field :timestamp, 5, optional: true, type: :uint64
    field :congestion_level, 6, optional: true, type: __MODULE__.CongestionLevel, enum: true
    field :occupancy_status, 9, optional: true, type: __MODULE__.OccupancyStatus, enum: true
  end

  defmodule TimeRange do
    use Protobuf, syntax: :proto2

    field :start, 1, optional: true, type: :uint64
    field :end, 2, optional: true, type: :uint64
  end

  defmodule TranslatedString do
    use Protobuf, syntax: :proto2

    defmodule Translation do
      use Protobuf, syntax: :proto2

      field :text, 1, required: true, type: :string
      field :language, 2, optional: true, type: :string
    end

    field :translation, 1, repeated: true, type: __MODULE__.Translation
  end

  defmodule EntitySelector do
    use Protobuf, syntax: :proto2

    field :agency_id, 1, optional: true, type: :string
    field :route_id, 2, optional: true, type: :string
    field :route_type, 3, optional: true, type: :int32
    field :trip, 4, optional: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.TripDescriptor
    field :stop_id, 5, optional: true, type: :string
  end

  defmodule Alert do
    use Protobuf, syntax: :proto2

    defmodule Cause do
      use Protobuf, enum: true, syntax: :proto2
      field :UNKNOWN_CAUSE, 1
      field :OTHER_CAUSE, 2
      field :TECHNICAL_PROBLEM, 3
      field :STRIKE, 4
      field :DEMONSTRATION, 5
      field :ACCIDENT, 6
      field :HOLIDAY, 7
      field :WEATHER, 8
      field :MAINTENANCE, 9
      field :CONSTRUCTION, 10
      field :POLICE_ACTIVITY, 11
      field :MEDICAL_EMERGENCY, 12
    end

    defmodule Effect do
      use Protobuf, enum: true, syntax: :proto2
      field :NO_SERVICE, 1
      field :REDUCED_SERVICE, 2
      field :SIGNIFICANT_DELAYS, 3
      field :DETOUR, 4
      field :ADDITIONAL_SERVICE, 5
      field :MODIFIED_SERVICE, 6
      field :OTHER_EFFECT, 7
      field :UNKNOWN_EFFECT, 8
      field :STOP_MOVED, 9
    end

    field :active_period, 1, repeated: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.TimeRange
    field :informed_entity, 5, repeated: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.EntitySelector
    field :cause, 6, optional: true, type: __MODULE__.Cause, enum: true, default: 1
    field :effect, 7, optional: true, type: __MODULE__.Effect, enum: true, default: 8
    field :url, 8, optional: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.TranslatedString
    field :header_text, 10, optional: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.TranslatedString
    field :description_text, 11, optional: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.TranslatedString
  end

  defmodule FeedHeader do
    use Protobuf, syntax: :proto2

    defmodule Incrementality do
      use Protobuf, enum: true, syntax: :proto2
      field :FULL_DATASET, 0
      field :DIFFERENTIAL, 1
    end

    field :gtfs_realtime_version, 1, required: true, type: :string
    field :incrementality, 2, optional: true, type: __MODULE__.Incrementality, enum: true, default: 0
    field :timestamp, 3, optional: true, type: :uint64
  end

  defmodule FeedEntity do
    use Protobuf, syntax: :proto2

    field :id, 1, required: true, type: :string
    field :is_deleted, 2, optional: true, type: :bool, default: false
    field :trip_update, 3, optional: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.TripUpdate
    field :vehicle, 4, optional: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.VehiclePosition
    field :alert, 5, optional: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.Alert
  end

  defmodule FeedMessage do
    use Protobuf, syntax: :proto2

    field :header, 1, required: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.FeedHeader
    field :entity, 2, repeated: true, type: PhoenixApp0625.GtfsRt.GtfsRealtime.FeedEntity
  end
end