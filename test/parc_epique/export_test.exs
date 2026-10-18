defmodule ParcEpique.ExportTest do
  # Not async: writes to the shared test storage directory.
  use ParcEpique.DataCase
  use Oban.Testing, repo: ParcEpique.Repo

  import ParcEpique.AccountsFixtures

  alias ParcEpique.{Export, Playgrounds, Storage}
  alias ParcEpique.Playgrounds.Playground
  alias ParcEpique.Workers.ExportPlaygrounds

  setup do
    File.rm_rf!(Storage.root())
    :ok
  end

  defp playground(attrs) do
    Repo.insert!(
      Playground.changeset(
        %Playground{},
        Map.merge(%{location: Playground.point(48.8386, 2.3536)}, attrs)
      )
    )
  end

  defp read_export do
    Storage.path(Export.key()) |> File.read!() |> Jason.decode!()
  end

  test "writes a GeoJSON file of the visible playgrounds, with its licence" do
    scipion = playground(%{name: "Square Scipion", osm_type: "node", osm_id: 42})
    unnamed = playground(%{location: Playground.point(50.6, 3.08)})
    playground(%{status: "hidden"})

    assert {:ok, 2} = Export.generate()

    assert %{
             "type" => "FeatureCollection",
             "license" => "ODbL-1.0",
             "attribution" => attribution,
             "features" => [first, second]
           } = read_export()

    assert attribution =~ "OpenStreetMap"

    assert %{
             "type" => "Feature",
             "id" => id,
             "geometry" => %{"type" => "Point", "coordinates" => [2.3536, 48.8386]},
             "properties" => %{"name" => "Square Scipion", "osm" => "node/42", "reviews" => 0}
           } = first

    assert id == scipion.id

    assert %{"id" => unnamed_id, "geometry" => %{"coordinates" => [3.08, 50.6]}} = second
    assert unnamed_id == unnamed.id
    refute Map.has_key?(second["properties"], "name")
  end

  test "an empty database gives an empty collection" do
    assert {:ok, 0} = Export.generate()
    assert %{"features" => []} = read_export()
  end

  test "holds the validated details and the average ratings, nothing about people" do
    place = playground(%{name: "Square Scipion"})
    alice = user_fixture(%{email: "alice-secret@example.com"})
    bob = user_fixture(%{email: "bob-secret@example.com"})

    for {user, surroundings, equipment, comment} <- [
          {alice, "4", "3", "alice-comment"},
          {bob, "5", "4", "bob-comment"}
        ] do
      {:ok, _} =
        Playgrounds.save_review(place, user, %{
          "rating_surroundings" => surroundings,
          "rating_equipment" => equipment,
          "comment" => comment
        })
    end

    {:ok, validated} =
      Playgrounds.propose_details(place, alice, %{"equipment" => ["slide"], "free" => "true"})

    {:ok, _pending} = Playgrounds.propose_details(place, bob, %{"equipment" => ["sandpit"]})
    {:ok, _} = ParcEpique.Moderation.validate_detail(validated.id)

    assert {:ok, 1} = Export.generate()

    raw = File.read!(Storage.path(Export.key()))
    assert %{"features" => [%{"properties" => properties}]} = Jason.decode!(raw)

    assert %{
             "reviews" => 2,
             "rating_surroundings" => 4.5,
             "rating_equipment" => 3.5,
             "equipment" => ["slide"],
             "free" => true
           } = properties

    refute Map.has_key?(properties, "open_at_night")

    for secret <- ["secret@", "comment", "user_id", "legacy_author", "uid", "display_name"] do
      refute raw =~ secret
    end
  end

  test "the previous export is kept until the new one is complete" do
    playground(%{name: "Square Scipion"})
    assert {:ok, 1} = Export.generate()
    first_date = Export.generated_at()

    playground(%{name: "Parc Monceau"})
    assert {:ok, 2} = Export.generate()

    assert length(read_export()["features"]) == 2
    refute File.exists?(Storage.path(Export.key()) <> ".tmp")
    assert DateTime.compare(Export.generated_at(), first_date) in [:gt, :eq]
  end

  test "has no date before the first export" do
    assert Export.generated_at() == nil
  end

  test "the job generates the export" do
    playground(%{name: "Square Scipion"})

    assert :ok = perform_job(ExportPlaygrounds, %{})
    assert %{"features" => [_]} = read_export()
  end
end
