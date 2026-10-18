defmodule Mix.Tasks.ParcEpique.Export do
  @shortdoc "Generates the public GeoJSON export of the playgrounds"

  @moduledoc """
  Generates the public export now, instead of waiting for the nightly job.

      mix parc_epique.export
  """
  use Mix.Task

  @requirements ["app.start"]

  @impl true
  def run(_args) do
    {:ok, count} = ParcEpique.Export.generate()

    Mix.shell().info(
      "#{count} playgrounds exported to #{ParcEpique.Storage.path(ParcEpique.Export.key())}"
    )
  end
end
