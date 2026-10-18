defmodule ParcEpiqueWeb.LegacyUrlsTest do
  use ParcEpiqueWeb.ConnCase, async: true

  test "the start page of the installed old app leads to the map", %{conn: conn} do
    assert conn |> get("/index.html") |> redirected_to() == "/fr"
  end

  test "the paths of the old site lead to their equivalents", %{conn: conn} do
    assert conn |> get("/apropos") |> redirected_to() == "/fr/a-propos"
    assert conn |> get("/login") |> redirected_to() == "/users/log-in"
  end

  test "the old service worker is replaced by one that removes itself", %{conn: conn} do
    script = conn |> get("/service-worker.js") |> response(200)

    assert script =~ "caches.delete"
    assert script =~ "registration.unregister()"
  end

  test "the app redirects the hash URLs of the old site" do
    app = File.read!("assets/js/app.js")
    assert app =~ "redirectLegacyUrl()"
    assert File.read!("assets/js/legacy_urls.js") =~ "/a-propos"
  end
end
