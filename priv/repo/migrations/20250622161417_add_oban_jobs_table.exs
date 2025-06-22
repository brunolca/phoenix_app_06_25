defmodule PhoenixApp0625.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  def change do
    Oban.Migration.up(version: 12, prefix: false)
  end
end
