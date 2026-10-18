defmodule ParcEpiqueWeb.ExportController do
  use ParcEpiqueWeb, :controller

  alias ParcEpique.{Export, Storage}

  @doc "Downloads the latest export (see `ParcEpique.Export`)."
  def geojson(conn, _params) do
    path = Storage.path(Export.key())

    if File.regular?(path) do
      conn
      |> put_resp_content_type("application/geo+json")
      |> put_resp_header(
        "content-disposition",
        ~s(attachment; filename="parc-epique-aires.geojson")
      )
      |> put_resp_header("cache-control", "public, max-age=3600")
      |> send_file(200, path)
    else
      send_resp(conn, :not_found, "Not Found")
    end
  end
end
