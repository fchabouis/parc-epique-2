defmodule ParcEpiqueWeb.Plugs.HealthTest do
  use ParcEpiqueWeb.ConnCase, async: true

  test "GET /health answers when the database does", %{conn: conn} do
    conn = get(conn, "/health")

    assert response(conn, 200) == "ok"
    assert get_resp_header(conn, "cache-control") == ["no-store"]
  end
end
