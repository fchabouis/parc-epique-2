defmodule ParcEpique.Legacy.FirebaseImportTest do
  use ParcEpique.DataCase, async: true

  alias ParcEpique.Legacy.FirebaseImport
  alias ParcEpique.Playgrounds.{Detail, Photo, Playground, RemovalReport, Review}

  @fixture "test/support/fixtures/firebase_export.json"

  test "imports every Firebase node" do
    assert {:ok, report} = FirebaseImport.run(@fixture)

    assert report.playgrounds == %{imported: 3, skipped: ["aire-broken"]}
    assert report.details == %{imported: 2, orphans: 1, unknown_equipment: ["trampoline"]}
    assert report.reviews == %{imported: 2, orphans: 0}
    assert report.photos == %{imported: 1, orphans: 0}
    assert report.removal_reports == %{imported: 1, orphans: 0}
    assert report.raw_osm_not_on_map == 1

    square = Repo.get_by!(Playground, legacy_key: "node-1031945363")
    assert %{osm_type: "node", osm_id: 1_031_945_363, source: "osm"} = square
    assert square.name == "Square du Manège"
    assert square.location == %Geo.Point{coordinates: {3.0809135, 50.638265}, srid: 4326}

    assert %{osm_type: "way", osm_id: 26_541_913, name: nil} =
             Repo.get_by!(Playground, legacy_key: "way-26541913")

    added = Repo.get_by!(Playground, legacy_key: "aire-1515776975678")
    assert %{source: "user", osm_id: nil, legacy_author_uid: "uid-a"} = added
    assert added.inserted_at == ~U[2018-01-12 17:09:35Z]

    detail = Repo.get_by!(Detail, legacy_key: "-L3SLTUT-qfC0odyD96H")

    assert %{
             equipment: ["climbingframe", "rope_traverse"],
             free: true,
             open_at_night: true,
             private: false,
             status: "validated"
           } = detail

    assert detail.playground_id == added.id

    # Booleans stored as strings in Firebase
    assert %{free: false, open_at_night: true, private: nil} =
             Repo.get_by!(Detail, legacy_key: "-Lyyyyy")

    review = Repo.get_by!(Review, legacy_author_uid: "uid-a")

    assert %{
             rating_equipment: 3.5,
             rating_surroundings: 4.0,
             comment: "Très joli petit square au calme !",
             display_name: nil
           } = review

    assert %{verified: false, thumbnail_path: "https://" <> _} =
             Repo.get_by!(Photo, legacy_key: "node-1031945363/1600000000000")

    assert %{reason: "L'aire a été démontée", status: "pending"} =
             Repo.get_by!(RemovalReport, legacy_key: "way-26541913")
  end

  test "running the import twice changes nothing" do
    {:ok, _} = FirebaseImport.run(@fixture)
    counts = counts()

    {:ok, _} = FirebaseImport.run(@fixture)
    assert counts() == counts
  end

  test "keeps moderation decisions made after a first import" do
    {:ok, _} = FirebaseImport.run(@fixture)

    Repo.get_by!(Playground, legacy_key: "way-26541913")
    |> Ecto.Changeset.change(status: "hidden")
    |> Repo.update!()

    {:ok, _} = FirebaseImport.run(@fixture)
    assert Repo.get_by!(Playground, legacy_key: "way-26541913").status == "hidden"
  end

  test "parses OSM keys" do
    assert FirebaseImport.parse_osm_key("node-1002710280") == {"node", 1_002_710_280}
    assert FirebaseImport.parse_osm_key("relation-42") == {"relation", 42}
    assert FirebaseImport.parse_osm_key("aire-1515776975678") == {nil, nil}
    assert FirebaseImport.parse_osm_key("area_1515776087927") == {nil, nil}
    assert FirebaseImport.parse_osm_key("node-12abc") == {nil, nil}
  end

  # The public export of August 2022 published with the old site; CI downloads it.
  @public_export "tmp/base_repartage_2022_08_22.json"
  @tag :legacy_export
  @tag timeout: :infinity
  test "imports the public 2022 export" do
    assert {:ok, report} = FirebaseImport.run(@public_export)

    assert report.playgrounds.imported == 16_914
    assert report.reviews.imported == 686
    assert Repo.aggregate(Playground, :count) == 16_914
    assert Repo.aggregate(Review, :count) == 686
    assert Repo.aggregate(Detail, :count) == 489
    assert report.details == %{imported: 489, orphans: 0, unknown_equipment: []}
  end

  defp counts do
    for schema <- [Playground, Detail, Review, Photo, RemovalReport],
        do: Repo.aggregate(schema, :count)
  end
end
