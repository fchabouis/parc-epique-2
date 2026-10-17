defmodule ParcEpiqueWeb.Plugs.UploadsTest do
  use ParcEpiqueWeb.ConnCase

  alias ParcEpique.Storage

  test "stored files are served at /uploads", %{conn: conn} do
    source =
      Path.join(System.tmp_dir!(), "uploads_test_#{System.unique_integer([:positive])}.jpg")

    Image.write!(Image.new!(20, 20, color: :green), source)
    on_exit(fn -> File.rm(source) end)

    :ok = Storage.put_file(source, "photos/test/served.jpg")

    conn = get(conn, "/uploads/photos/test/served.jpg")
    assert conn.status == 200
    assert ["image/jpeg" <> _] = get_resp_header(conn, "content-type")
  end

  test "storage keys cannot leave the storage root" do
    assert_raise ArgumentError, fn -> Storage.path("../config/prod.exs") end
    assert_raise ArgumentError, fn -> Storage.path("/etc/passwd") end
  end
end
