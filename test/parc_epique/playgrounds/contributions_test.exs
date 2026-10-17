defmodule ParcEpique.Playgrounds.ContributionsTest do
  use ParcEpique.DataCase, async: true

  alias ParcEpique.Playgrounds.{Detail, Equipment, Photo, Playground, RemovalReport, Review}

  setup do
    playground =
      Repo.insert!(
        Playground.changeset(%Playground{}, %{
          legacy_key: "aire-1515776975678",
          source: "user",
          location: Playground.point(48.838692, 2.353633)
        })
      )

    %{playground: playground}
  end

  describe "reviews" do
    test "accepts half-point ratings from 0 to 5", %{playground: playground} do
      changeset =
        Review.changeset(%Review{}, %{
          playground_id: playground.id,
          rating_surroundings: 3.5,
          rating_equipment: 5,
          comment: "Très joli petit square au calme",
          legacy_author_uid: "uid-1"
        })

      assert changeset.valid?
      assert Repo.insert!(changeset).rating_equipment == 5.0
    end

    test "rejects ratings out of range or not on a half point", %{playground: playground} do
      changeset =
        Review.changeset(%Review{}, %{
          playground_id: playground.id,
          rating_surroundings: 5.5,
          rating_equipment: 3.2
        })

      assert %{rating_surroundings: [_], rating_equipment: ["must be a half point"]} =
               errors_on(changeset)
    end

    test "one review per author and playground", %{playground: playground} do
      attrs = %{playground_id: playground.id, rating_equipment: 4, legacy_author_uid: "uid-1"}
      Repo.insert!(Review.changeset(%Review{}, attrs))

      assert {:error, changeset} = Repo.insert(Review.changeset(%Review{}, attrs))
      assert %{playground_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "requires an existing playground" do
      assert {:error, changeset} =
               Repo.insert(Review.changeset(%Review{}, %{playground_id: -1, rating_equipment: 4}))

      assert %{playground: ["does not exist"]} = errors_on(changeset)
    end
  end

  describe "details" do
    test "only accept known equipment codes", %{playground: playground} do
      assert Detail.changeset(%Detail{}, %{
               playground_id: playground.id,
               equipment: ["slide", "sandpit"],
               free: true
             }).valid?

      changeset =
        Detail.changeset(%Detail{}, %{playground_id: playground.id, equipment: ["toboggan"]})

      assert %{equipment: [_]} = errors_on(changeset)
    end

    test "Firebase labels map to codes" do
      assert Equipment.from_legacy_label("cheval à bascule") == {:ok, "springy"}
      assert Equipment.from_legacy_label(" Toboggan ") == {:ok, "slide"}
      assert Equipment.from_legacy_label("trampoline") == :error

      for {:ok, code} <-
            Enum.map(["toboggan", "pont de singe", "tourniquet"], &Equipment.from_legacy_label/1) do
        assert code in Equipment.codes()
      end
    end
  end

  test "photos start unverified", %{playground: playground} do
    photo =
      Repo.insert!(
        Photo.changeset(%Photo{}, %{
          playground_id: playground.id,
          path: "photos/aire-1515776975678/original.jpg",
          thumbnail_path: "photos/aire-1515776975678/thumb_original.jpg"
        })
      )

    refute photo.verified
  end

  test "removal reports start pending", %{playground: playground} do
    report =
      Repo.insert!(RemovalReport.changeset(%RemovalReport{}, %{playground_id: playground.id}))

    assert report.status == "pending"
  end
end
