defmodule Mix.Tasks.ParcEpique.ImportPhotos do
  @shortdoc "Copies the photos exported from Firebase Storage"

  @moduledoc """
  Copies the photos and thumbnails exported from Firebase Storage into the
  application storage, after `mix parc_epique.import_firebase`.

      mix parc_epique.import_photos export/photos

  See `ParcEpique.Legacy.PhotoImport`.
  """
  use Mix.Task

  alias ParcEpique.Legacy.PhotoImport

  @requirements ["app.start"]

  @impl Mix.Task
  def run([dir]) do
    report = PhotoImport.run(dir)

    Mix.shell().info("""
    Photos importées : #{report.imported} (dont #{report.thumbnails_generated} miniatures régénérées)
    Photos sans fichier dans l'export : #{length(report.missing)} #{Enum.join(report.missing, ", ")}
    Échecs : #{length(report.failed)} #{inspect(report.failed)}
    Fichiers de l'export non utilisés : #{length(report.unused_files)}
    Téléchargements inachevés (.gstmp, à relancer) : #{length(report.partial_downloads)}
    """)
  end

  def run(_args) do
    Mix.raise("Usage: mix parc_epique.import_photos path/to/photos")
  end
end
