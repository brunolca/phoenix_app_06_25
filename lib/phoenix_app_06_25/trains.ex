defmodule PhoenixApp0625.Trains do
  @moduledoc """
  The Trains context.
  """

  import Ecto.Query, warn: false
  alias PhoenixApp0625.Repo
  alias PhoenixApp0625.Trains.Train

  @doc """
  Returns the list of active trains.
  """
  def list_active_trains do
    Repo.all(from t in Train, where: t.is_active == true, order_by: [desc: t.timestamp])
  end

  @doc """
  Returns the list of trains within a geographic bounding box.
  """
  def list_trains_in_bounds(min_lat, max_lat, min_lng, max_lng) do
    query = from t in Train,
      where: t.is_active == true,
      where: t.latitude >= ^min_lat and t.latitude <= ^max_lat,
      where: t.longitude >= ^min_lng and t.longitude <= ^max_lng,
      order_by: [desc: t.timestamp]

    Repo.all(query)
  end

  @doc """
  Gets a single train by train number and trip id.
  """
  def get_train(train_number, trip_id) do
    Repo.get_by(Train, train_number: train_number, trip_id: trip_id)
  end

  @doc """
  Creates or updates a train.
  """
  def upsert_train(attrs \\ %{}) do
    %Train{}
    |> Train.changeset(attrs)
    |> Repo.insert(
      on_conflict: :replace_all,
      conflict_target: [:train_number, :trip_id]
    )
  end

  @doc """
  Deactivates trains that haven't been updated recently.
  """
  def deactivate_stale_trains(minutes_ago \\ 30) do
    cutoff_time = DateTime.utc_now() |> DateTime.add(-minutes_ago * 60, :second)

    from(t in Train,
      where: t.timestamp < ^cutoff_time,
      where: t.is_active == true
    )
    |> Repo.update_all(set: [is_active: false])
  end
end
