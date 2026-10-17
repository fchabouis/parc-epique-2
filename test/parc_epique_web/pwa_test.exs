defmodule ParcEpiqueWeb.PWATest do
  use ParcEpiqueWeb.ConnCase, async: true

  defp manifest(conn) do
    conn |> get("/manifest.webmanifest") |> response(200) |> Jason.decode!()
  end

  test "the manifest makes the site installable", %{conn: conn} do
    manifest = manifest(conn)

    assert %{
             "name" => "Parc Épique",
             "short_name" => "Parc Épique",
             "display" => "standalone",
             "start_url" => "/",
             "background_color" => "#d7ffe8",
             "theme_color" => "#1bd980"
           } = manifest

    sizes = Enum.map(manifest["icons"], & &1["sizes"])
    assert "192x192" in sizes
    assert "512x512" in sizes
  end

  test "the icons of the manifest are served, at the size they announce", %{conn: conn} do
    for %{"src" => src, "sizes" => sizes, "type" => "image/png"} <- manifest(conn)["icons"] do
      body = conn |> get(src) |> response(200)

      # The size is in the PNG header, after the 8-byte signature and the IHDR tag.
      assert <<137, "PNG", _::binary-size(12), width::32, height::32, _::binary>> = body
      assert "#{width}x#{height}" == sizes
    end
  end

  test "the page links the manifest and the iOS icon", %{conn: conn} do
    html = conn |> get(~p"/fr") |> html_response(200)

    assert html =~ ~s(rel="manifest" href="/manifest.webmanifest")
    assert html =~ ~s(name="theme-color" content="#1bd980")
    assert html =~ ~s(rel="apple-touch-icon" href="/images/icons/apple-touch-icon.png")
    assert conn |> get("/images/icons/apple-touch-icon.png") |> response(200)
  end

  test "the service worker is served from the root, with the offline page", %{conn: conn} do
    script = conn |> get("/sw.js") |> response(200)
    assert script =~ ~s("fetch")
    assert script =~ "/offline.html"

    assert conn |> get("/offline.html") |> html_response(200) =~ "hors connexion"
  end

  test "the app registers the service worker" do
    app = File.read!("assets/js/app.js")
    assert app =~ ~s[serviceWorker.register("/sw.js")]
  end
end
