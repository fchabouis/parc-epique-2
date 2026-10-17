defmodule ParcEpiqueWeb.AboutAndExportTest do
  # Not async: writes to the shared test storage directory.
  use ParcEpiqueWeb.ConnCase

  alias ParcEpique.{Export, Storage}
  alias ParcEpique.Playgrounds.Playground
  alias ParcEpique.Repo

  setup do
    File.rm_rf!(Storage.root())
    :ok
  end

  test "the About page credits OpenStreetMap and the ODbL", %{conn: conn} do
    html = conn |> get(~p"/fr/a-propos") |> html_response(200)

    assert html =~ "Les enfants ne sont pas beaucoup dehors"
    assert html =~ "openstreetmap.org/copyright"
    assert html =~ "ODbL"
    assert html =~ ~s(id="data")
  end

  test "the download link appears once the export exists", %{conn: conn} do
    html = conn |> get(~p"/fr/a-propos") |> html_response(200)
    refute html =~ "/export/aires.geojson"
    assert html =~ "L&#39;export est généré chaque nuit"

    Repo.insert!(Playground.changeset(%Playground{}, %{location: Playground.point(48.8, 2.35)}))

    {:ok, 1} = Export.generate()

    html = conn |> get(~p"/fr/a-propos") |> html_response(200)
    assert html =~ ~s(href="/export/aires.geojson")
    assert html =~ "Mis à jour le"
  end

  test "the export is downloaded as GeoJSON", %{conn: conn} do
    Repo.insert!(
      Playground.changeset(%Playground{}, %{
        name: "Square Scipion",
        location: Playground.point(48.8, 2.35)
      })
    )

    {:ok, 1} = Export.generate()

    conn = get(conn, ~p"/export/aires.geojson")

    assert response(conn, 200)
    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "application/geo+json"

    assert %{"features" => [%{"properties" => %{"name" => "Square Scipion"}}]} =
             Jason.decode!(conn.resp_body)
  end

  test "there is no download before the first export", %{conn: conn} do
    assert conn |> get(~p"/export/aires.geojson") |> response(404)
  end

  test "the map and the sheet credit OpenStreetMap", %{conn: conn} do
    playground =
      Repo.insert!(Playground.changeset(%Playground{}, %{location: Playground.point(48.8, 2.35)}))

    html = conn |> get(~p"/fr") |> html_response(200)
    assert html =~ ~s(data-attribution-url="/fr/a-propos#data")

    html = conn |> get(~p"/fr/aires/#{playground.id}") |> html_response(200)
    assert html =~ "Données © contributeurs d&#39;OpenStreetMap (ODbL)"
  end
end
