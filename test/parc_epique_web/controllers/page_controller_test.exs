defmodule ParcEpiqueWeb.PageControllerTest do
  use ParcEpiqueWeb.ConnCase

  test "GET / redirects to the default locale", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert redirected_to(conn) == ~p"/fr"
  end

  test "GET /fr", %{conn: conn} do
    conn = get(conn, ~p"/fr")
    assert html_response(conn, 200) =~ "Parc Épique"
  end

  test "GET with an unknown locale is a 404", %{conn: conn} do
    conn = get(conn, ~p"/xx")
    assert html_response(conn, 404)
  end
end
