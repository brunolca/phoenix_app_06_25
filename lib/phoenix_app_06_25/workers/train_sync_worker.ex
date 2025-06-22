defmodule PhoenixApp0625.Workers.TrainSyncWorker do
  @moduledoc """
  Oban worker for fetching and processing real-time train data from SNCF API.
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  require Logger
  alias PhoenixApp0625.SncfClient

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    Logger.info("Starting train sync job...")

    try do
      case SncfClient.fetch_and_process_updates() do
        {:ok, trains} ->
          Logger.info("Successfully updated #{length(trains)} trains")
          :ok

        {:error, reason} ->
          Logger.error("Train sync job failed: #{inspect(reason)}")
          {:snooze, 30}
      end
    rescue
      error ->
        Logger.error("Train sync job crashed: #{inspect(error)}")
        {:snooze, 60}
    end
  end
end
