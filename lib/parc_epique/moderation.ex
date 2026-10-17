defmodule ParcEpique.Moderation do
  @moduledoc """
  What administrators do with the contributions of visitors: check the
  playgrounds they add, validate the details they propose, verify their
  photos, act on removal reports and delete abusive reviews.
  """

  import Ecto.Query

  alias ParcEpique.Playgrounds.{Detail, Photo, Playground, RemovalReport, Review}
  alias ParcEpique.{Repo, Storage}

  @page 50

  @doc "The number of items waiting for each kind of moderation."
  def counts do
    %{
      playgrounds: Repo.aggregate(unchecked_playgrounds(), :count),
      details: Repo.aggregate(pending_details(), :count),
      photos: Repo.aggregate(unverified_photos(), :count),
      reports: Repo.aggregate(pending_reports(), :count)
    }
  end

  ## Playgrounds added by visitors

  defp unchecked_playgrounds, do: from(p in Playground, where: not p.checked)

  @doc "Playgrounds added from the site and not checked yet, oldest first."
  def list_unchecked_playgrounds do
    unchecked_playgrounds()
    |> order_by([p], asc: p.inserted_at, asc: p.id)
    |> limit(@page)
    |> preload(:user)
    |> Repo.all()
  end

  @doc "Keeps a playground added by a visitor."
  def check_playground(id), do: change_record(Playground, id, checked: true)

  @doc "Hides a playground from the map and the site."
  def hide_playground(id), do: change_record(Playground, id, status: "hidden", checked: true)

  ## Details

  defp pending_details, do: from(d in Detail, where: d.status == "pending")

  @doc "Details proposed by visitors and not validated yet, oldest first."
  def list_pending_details do
    pending_details()
    |> order_by([d], asc: d.inserted_at, asc: d.id)
    |> limit(@page)
    |> preload(:user)
    |> Repo.all()
  end

  def validate_detail(id), do: change_record(Detail, id, status: "validated")

  def reject_detail(id), do: change_record(Detail, id, status: "rejected")

  ## Photos

  defp unverified_photos, do: from(ph in Photo, where: not ph.verified)

  @doc "Photos nobody has checked yet, newest first."
  def list_unverified_photos do
    unverified_photos()
    |> order_by([ph], desc: ph.inserted_at, desc: ph.id)
    |> limit(@page)
    |> preload(:user)
    |> Repo.all()
  end

  def verify_photo(id), do: change_record(Photo, id, verified: true)

  @doc "Deletes a photo, its thumbnail and their files."
  def delete_photo(id) do
    case Repo.get(Photo, id) do
      nil ->
        {:error, :not_found}

      photo ->
        with {:ok, photo} <- Repo.delete(photo) do
          for key <- [photo.path, photo.thumbnail_path], stored?(key), do: Storage.delete(key)
          {:ok, photo}
        end
    end
  end

  # Photos not copied from Firebase yet are still addressed by URL.
  defp stored?(key), do: is_binary(key) and not String.starts_with?(key, "http")

  ## Removal reports

  defp pending_reports, do: from(r in RemovalReport, where: r.status == "pending")

  @doc "Reports that a playground no longer exists, oldest first."
  def list_pending_reports do
    pending_reports()
    |> order_by([r], asc: r.inserted_at, asc: r.id)
    |> limit(@page)
    |> preload(:user)
    |> Repo.all()
  end

  @doc """
  Accepts a report: the playground is hidden and every pending report about
  it is closed.
  """
  def accept_report(id) do
    case Repo.get(RemovalReport, id) do
      nil ->
        {:error, :not_found}

      %RemovalReport{playground_id: playground_id} ->
        Repo.transact(fn ->
          from(p in Playground, where: p.id == ^playground_id)
          |> Repo.update_all(set: [status: "hidden"])

          from(r in RemovalReport,
            where: r.playground_id == ^playground_id and r.status == "pending"
          )
          |> Repo.update_all(set: [status: "accepted"])

          {:ok, Repo.get!(RemovalReport, id)}
        end)
    end
  end

  def reject_report(id), do: change_record(RemovalReport, id, status: "rejected")

  ## Reviews

  @doc "The latest reviews, to find abusive ones."
  def list_recent_reviews do
    from(r in Review, order_by: [desc: r.inserted_at, desc: r.id], limit: ^@page)
    |> preload(:user)
    |> Repo.all()
  end

  def delete_review(id) do
    case Repo.get(Review, id) do
      nil -> {:error, :not_found}
      review -> Repo.delete(review)
    end
  end

  ## Feed

  @doc """
  The latest contributions of every kind, newest first, as maps with `:kind`,
  `:id`, `:at`, `:playground_id` and `:author` (a `User` or `nil`).
  """
  def recent_contributions(limit \\ 30) do
    [
      {:playground, from(p in Playground, where: p.source == "user"), :id},
      {:detail, Detail, :playground_id},
      {:photo, Photo, :playground_id},
      {:report, RemovalReport, :playground_id},
      {:review, Review, :playground_id}
    ]
    |> Enum.flat_map(fn {kind, queryable, playground_field} ->
      recent(queryable, playground_field, limit) |> Enum.map(&Map.put(&1, :kind, kind))
    end)
    |> Enum.sort_by(& &1.at, {:desc, DateTime})
    |> Enum.take(limit)
  end

  defp recent(queryable, playground_field, limit) do
    from(c in queryable,
      left_join: u in assoc(c, :user),
      order_by: [desc: c.inserted_at, desc: c.id],
      limit: ^limit,
      select: %{
        id: c.id,
        at: c.inserted_at,
        playground_id: field(c, ^playground_field),
        author: u
      }
    )
    |> Repo.all()
  end

  defp change_record(schema, id, changes) do
    case Repo.get(schema, id) do
      nil -> {:error, :not_found}
      record -> record |> Ecto.Changeset.change(changes) |> Repo.update()
    end
  end
end
