defmodule Mix.Tasks.ParcEpique.ImportFirebase do
  @shortdoc "Imports a Firebase database.json export"

  @moduledoc """
  Imports the Realtime Database export of the old site into PostgreSQL.

      mix parc_epique.import_firebase export/database.json

  It can be run again safely: existing rows are updated, not duplicated.
  See `ParcEpique.Legacy.FirebaseImport`.
  """
  use Mix.Task

  alias ParcEpique.Legacy.FirebaseImport

  @requirements ["app.start"]

  @impl Mix.Task
  def run([path]) do
    {:ok, report} = FirebaseImport.run(path)

    Mix.shell().info("""
    Aires de jeux : #{report.playgrounds.imported} importées, #{length(report.playgrounds.skipped)} ignorées (sans coordonnées)
    Détails : #{report.details.imported} importés, #{report.details.orphans} sans aire
    Équipements inconnus : #{Enum.join(report.details.unknown_equipment, ", ")}
    Avis : #{report.reviews.imported} importés, #{report.reviews.orphans} sans aire
    Photos : #{report.photos.imported} importées, #{report.photos.orphans} sans aire ou sans URL
    Signalements : #{report.removal_reports.imported} importés, #{report.removal_reports.orphans} sans aire
    Aires OSM brutes absentes de la carte : #{report.raw_osm_not_on_map}
    """)
  end

  def run(_args) do
    Mix.raise("Usage: mix parc_epique.import_firebase path/to/database.json")
  end
end
