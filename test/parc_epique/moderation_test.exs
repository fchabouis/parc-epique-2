defmodule ParcEpique.ModerationTest do
  # Not async: photos are files in the shared test storage directory.
  use ParcEpique.DataCase

  import ParcEpique.AccountsFixtures

  alias ParcEpique.{Moderation, Playgrounds, Storage}
  alias ParcEpique.Playgrounds.{Detail, Photo, Playground, RemovalReport, Review}

  setup do
    File.rm_rf!(Storage.root())

    playground =
      Repo.insert!(
        Playground.changeset(%Playground{}, %{
          name: "Square Scipion",
          location: Playground.point(48.8386, 2.3536)
        })
      )

    %{playground: playground, user: user_fixture()}
  end

  test "playgrounds added by visitors are unchecked until kept or hidden", %{user: user} do
    {:ok, kept} = Playgrounds.add_playground(user, 48.85, 2.35)
    {:ok, hidden} = Playgrounds.add_playground(user, 48.86, 2.36)

    assert [kept.id, hidden.id] == Enum.map(Moderation.list_unchecked_playgrounds(), & &1.id)
    assert %{playgrounds: 2} = Moderation.counts()

    {:ok, _} = Moderation.check_playground(kept.id)
    {:ok, _} = Moderation.hide_playground(hidden.id)

    assert Moderation.list_unchecked_playgrounds() == []
    assert Repo.reload!(kept).status == "visible"
    assert Repo.reload!(hidden).status == "hidden"
  end

  test "details are validated or rejected", %{playground: p, user: user} do
    {:ok, validated} = Playgrounds.propose_details(p, user, %{"equipment" => ["slide"]})
    {:ok, rejected} = Playgrounds.propose_details(p, user, %{"free" => "false"})

    assert [_, _] = Moderation.list_pending_details()

    {:ok, _} = Moderation.validate_detail(validated.id)
    {:ok, _} = Moderation.reject_detail(rejected.id)

    assert Moderation.list_pending_details() == []
    assert Repo.reload!(validated).status == "validated"
    assert Repo.reload!(rejected).status == "rejected"
    assert [%Detail{id: id}] = Playgrounds.get_visible_playground!(p.id).details
    assert id == validated.id
  end

  test "photos are verified or deleted with their files", %{playground: p, user: user} do
    kept = insert_photo(p, user, "kept")
    deleted = insert_photo(p, user, "deleted")

    assert [_, _] = Moderation.list_unverified_photos()

    {:ok, _} = Moderation.verify_photo(kept.id)
    {:ok, _} = Moderation.delete_photo(deleted.id)

    assert Moderation.list_unverified_photos() == []
    assert Repo.reload!(kept).verified
    assert Repo.get(Photo, deleted.id) == nil
    assert Storage.exists?(kept.path)
    refute Storage.exists?(deleted.path)
    refute Storage.exists?(deleted.thumbnail_path)
  end

  test "deleting a photo still addressed by URL leaves the storage alone", %{playground: p} do
    photo =
      Repo.insert!(
        Photo.changeset(%Photo{}, %{
          playground_id: p.id,
          path: "https://storage.googleapis.com/bucket/photos/node-1/photo",
          thumbnail_path: "https://storage.googleapis.com/bucket/photos/node-1/thumb_photo"
        })
      )

    assert {:ok, _} = Moderation.delete_photo(photo.id)
    assert Repo.get(Photo, photo.id) == nil
  end

  test "accepting a report hides the playground and closes the other reports", %{
    playground: p,
    user: user
  } do
    {:ok, report} = Playgrounds.report_removal(p, user)
    {:ok, other} = Playgrounds.report_removal(p, user_fixture())

    assert %{reports: 2} = Moderation.counts()
    assert {:ok, %RemovalReport{status: "accepted"}} = Moderation.accept_report(report.id)

    assert Repo.reload!(p).status == "hidden"
    assert Repo.reload!(other).status == "accepted"
    assert Moderation.list_pending_reports() == []
  end

  test "rejecting a report keeps the playground", %{playground: p, user: user} do
    {:ok, report} = Playgrounds.report_removal(p, user)

    assert {:ok, %RemovalReport{status: "rejected"}} = Moderation.reject_report(report.id)
    assert Repo.reload!(p).status == "visible"
  end

  test "reviews are deleted", %{playground: p, user: user} do
    {:ok, review} =
      Playgrounds.save_review(p, user, %{
        "rating_surroundings" => "4",
        "rating_equipment" => "3",
        "comment" => "spam"
      })

    assert [%Review{}] = Moderation.list_recent_reviews()
    assert {:ok, _} = Moderation.delete_review(review.id)
    assert Moderation.list_recent_reviews() == []
  end

  test "items that are gone give an error" do
    assert {:error, :not_found} = Moderation.validate_detail(0)
    assert {:error, :not_found} = Moderation.delete_photo(0)
    assert {:error, :not_found} = Moderation.accept_report(0)
    assert {:error, :not_found} = Moderation.delete_review(0)
  end

  test "the feed mixes every kind of contribution, newest first", %{playground: p, user: user} do
    {:ok, _} =
      Playgrounds.save_review(p, user, %{
        "rating_surroundings" => "4",
        "rating_equipment" => "3",
        "comment" => "nice"
      })

    {:ok, _} = Playgrounds.propose_details(p, user, %{"free" => "true"})
    {:ok, _} = Playgrounds.report_removal(p, user)
    {:ok, added} = Playgrounds.add_playground(user, 48.85, 2.35)
    insert_photo(p, user, "photo")

    feed = Moderation.recent_contributions()

    assert Enum.sort(Enum.map(feed, & &1.kind)) == [
             :detail,
             :photo,
             :playground,
             :report,
             :review
           ]

    assert Enum.find(feed, &(&1.kind == :playground)).playground_id == added.id
    assert Enum.all?(feed, &(&1.author.id == user.id))
    assert length(Moderation.recent_contributions(2)) == 2
  end

  defp insert_photo(playground, user, name) do
    path = "photos/#{playground.id}/#{name}.jpg"
    thumbnail_path = "photos/#{playground.id}/thumb_#{name}.jpg"
    source = Path.join(System.tmp_dir!(), "moderation_#{System.unique_integer([:positive])}.jpg")
    File.write!(source, "image")
    on_exit(fn -> File.rm(source) end)
    :ok = Storage.put_file(source, path)
    :ok = Storage.put_file(source, thumbnail_path)

    Repo.insert!(
      Photo.changeset(%Photo{}, %{
        playground_id: playground.id,
        user_id: user.id,
        path: path,
        thumbnail_path: thumbnail_path
      })
    )
  end
end
