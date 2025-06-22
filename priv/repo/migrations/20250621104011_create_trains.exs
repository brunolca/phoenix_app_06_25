defmodule PhoenixApp0625.Repo.Migrations.CreateTrains do
  use Ecto.Migration

  def change do
    create table(:trains) do
      add :train_number, :string, null: false
      add :operator, :string, null: false
      add :route_short_name, :string
      add :route_long_name, :string
      add :trip_id, :string
      add :direction_id, :integer
      add :current_stop_sequence, :integer
      add :current_status, :string
      add :timestamp, :utc_datetime
      add :latitude, :decimal, precision: 10, scale: 6
      add :longitude, :decimal, precision: 10, scale: 6
      add :bearing, :decimal, precision: 5, scale: 2
      add :speed_kmh, :decimal, precision: 5, scale: 2
      add :delay_seconds, :integer
      add :vehicle_id, :string
      add :gtfs_trip_id, :string
      add :is_active, :boolean, default: true

      timestamps()
    end

    create unique_index(:trains, [:train_number, :trip_id])
    create index(:trains, [:latitude, :longitude])
    create index(:trains, [:is_active])
    create index(:trains, [:timestamp])
  end
end
