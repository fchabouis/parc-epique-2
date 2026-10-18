defmodule ParcEpique.Workers.ExportPlaygrounds do
  @moduledoc """
  Regenerates the public export (`ParcEpique.Export`); scheduled every night
  by the Oban cron plugin.
  """
  use Oban.Worker, queue: :imports, max_attempts: 3, unique: [period: 3600]

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    with {:ok, _count} <- ParcEpique.Export.generate(), do: :ok
  end
end
