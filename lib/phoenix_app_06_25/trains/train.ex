defmodule PhoenixApp0625.Trains.Train do
  use Ecto.Schema
  import Ecto.Changeset

  schema "trains" do
    field :train_number, :string
    field :operator, :string
    field :route_short_name, :string
    field :route_long_name, :string
    field :trip_id, :string
    field :direction_id, :integer
    field :current_stop_sequence, :integer
    field :current_status, :string
    field :timestamp, :utc_datetime
    field :latitude, :decimal
    field :longitude, :decimal
    field :bearing, :decimal
    field :speed_kmh, :decimal
    field :delay_seconds, :integer
    field :vehicle_id, :string
    field :gtfs_trip_id, :string
    field :is_active, :boolean, default: true

    timestamps()
  end

  @doc false
  def changeset(train, attrs) do
    train
    |> cast(attrs, [
      :train_number, :operator, :route_short_name, :route_long_name,
      :trip_id, :direction_id, :current_stop_sequence, :current_status,
      :timestamp, :latitude, :longitude, :bearing, :speed_kmh,
      :delay_seconds, :vehicle_id, :gtfs_trip_id, :is_active
    ])
    |> validate_required([:train_number, :operator])
    |> validate_number(:latitude, greater_than_or_equal_to: -90, less_than_or_equal_to: 90)
    |> validate_number(:longitude, greater_than_or_equal_to: -180, less_than_or_equal_to: 180)
    |> validate_number(:bearing, greater_than_or_equal_to: 0, less_than: 360)
    |> validate_number(:speed_kmh, greater_than_or_equal_to: 0)
    |> unique_constraint([:train_number, :trip_id])
  end
end