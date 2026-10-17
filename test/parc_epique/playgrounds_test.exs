defmodule ParcEpique.PlaygroundsTest do
  use ParcEpique.DataCase, async: true

  alias ParcEpique.Playgrounds
  alias ParcEpique.Playgrounds.{Playground, Review}

  @lille %{south: 50.6, west: 3.0, north: 50.7, east: 3.2}

  defp insert_playground(lat, lon, attrs \\ %{}) do
    Repo.insert!(
      Playground.changeset(
        %Playground{},
        Map.merge(%{location: Playground.point(lat, lon)}, attrs)
      )
    )
  end

  test "lists visible playgrounds inside the bounds" do
    square = insert_playground(50.638265, 3.0809135, %{name: "Square du Manège"})
    insert_playground(50.65, 3.1, %{status: "hidden"})
    insert_playground(48.8386, 2.3536)

    assert {[found], false} = Playgrounds.list_in_bounds(@lille)
    assert %{id: id, name: "Square du Manège", reviewed: false} = found
    assert id == square.id
    assert found.location.coordinates == {3.0809135, 50.638265}
  end

  test "flags reviewed playgrounds and lists them first when truncated" do
    insert_playground(50.61, 3.01)
    reviewed = insert_playground(50.62, 3.02)
    Repo.insert!(Review.changeset(%Review{}, %{playground_id: reviewed.id, rating_equipment: 4}))

    assert {[first], true} = Playgrounds.list_in_bounds(@lille, limit: 1)
    assert first.id == reviewed.id
    assert first.reviewed
  end
end
