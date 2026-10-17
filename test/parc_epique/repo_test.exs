defmodule ParcEpique.RepoTest do
  use ParcEpique.DataCase, async: true

  test "PostGIS is installed and geometries round-trip" do
    point = %Geo.Point{coordinates: {2.3488, 48.8534}, srid: 4326}

    assert %{rows: [[%Geo.Point{coordinates: {2.3488, 48.8534}}]]} =
             Repo.query!("SELECT $1::geometry", [point])
  end
end
