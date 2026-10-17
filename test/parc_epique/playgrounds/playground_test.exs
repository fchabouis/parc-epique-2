defmodule ParcEpique.Playgrounds.PlaygroundTest do
  use ParcEpique.DataCase, async: true

  import Ecto.Query

  alias ParcEpique.Playgrounds.Playground

  @valid %{
    osm_type: "node",
    osm_id: 1_031_945_363,
    legacy_key: "node-1031945363",
    location: Playground.point(50.638265, 3.0809135),
    name: "Square du Manège"
  }

  test "valid attributes" do
    assert Playground.changeset(%Playground{}, @valid).valid?
  end

  test "requires a location" do
    changeset = Playground.changeset(%Playground{}, Map.delete(@valid, :location))
    assert %{location: ["can't be blank"]} = errors_on(changeset)
  end

  test "rejects a point outside WGS 84 bounds" do
    attrs = %{@valid | location: %Geo.Point{coordinates: {200.0, 48.0}, srid: 4326}}

    assert %{location: ["must be a WGS 84 point"]} =
             errors_on(Playground.changeset(%Playground{}, attrs))
  end

  test "rejects unknown OSM types, sources and statuses" do
    changeset =
      Playground.changeset(
        %Playground{},
        %{@valid | osm_type: "area"}
        |> Map.merge(%{source: "import", status: "deleted"})
      )

    assert %{osm_type: [_], source: [_], status: [_]} = errors_on(changeset)
  end

  test "OSM object and legacy key are unique" do
    Repo.insert!(Playground.changeset(%Playground{}, @valid))

    assert {:error, changeset} =
             Repo.insert(Playground.changeset(%Playground{}, %{@valid | legacy_key: "other"}))

    assert %{osm_type: ["has already been taken"]} = errors_on(changeset)

    assert {:error, changeset} =
             Repo.insert(Playground.changeset(%Playground{}, %{@valid | osm_id: 1}))

    assert %{legacy_key: ["has already been taken"]} = errors_on(changeset)
  end

  test "playgrounds can be found inside a bounding box" do
    Repo.insert!(Playground.changeset(%Playground{}, @valid))

    Repo.insert!(
      Playground.changeset(%Playground{}, %{
        legacy_key: "aire-1515776975678",
        source: "user",
        location: Playground.point(48.838692, 2.353633)
      })
    )

    lille =
      Repo.all(
        from p in Playground,
          where:
            fragment(
              "? && ST_MakeEnvelope(?, ?, ?, ?, 4326)",
              p.location,
              3.0,
              50.6,
              3.2,
              50.7
            ),
          select: p.legacy_key
      )

    assert lille == ["node-1031945363"]
  end
end
