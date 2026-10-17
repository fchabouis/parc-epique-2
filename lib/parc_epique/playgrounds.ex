defmodule ParcEpique.Playgrounds do
  @moduledoc """
  Playgrounds and their contributions.
  """

  import Ecto.Query

  alias ParcEpique.Playgrounds.{Detail, Photo, Playground, Review}
  alias ParcEpique.Repo

  @doc """
  Lists the visible playgrounds inside a bounding box (WGS 84 degrees), as
  maps with `:id`, `:name`, `:location` and `:reviewed` (true when the
  playground has at least one review).

  Returns `{playgrounds, truncated?}`: at most `:limit` playgrounds (3000 by
  default), reviewed ones first.
  """
  def list_in_bounds(%{south: south, west: west, north: north, east: east}, opts \\ []) do
    limit = Keyword.get(opts, :limit, 3000)

    rows =
      from(p in Playground,
        where: p.status == "visible",
        where:
          fragment(
            "? && ST_MakeEnvelope(?, ?, ?, ?, 4326)",
            p.location,
            ^west,
            ^south,
            ^east,
            ^north
          ),
        select: %{
          id: p.id,
          name: p.name,
          location: p.location,
          reviewed: fragment("EXISTS (SELECT 1 FROM reviews r WHERE r.playground_id = ?)", p.id)
        },
        order_by: [
          desc: fragment("EXISTS (SELECT 1 FROM reviews r WHERE r.playground_id = ?)", p.id),
          asc: p.id
        ],
        limit: ^(limit + 1)
      )
      |> Repo.all()

    {Enum.take(rows, limit), length(rows) > limit}
  end

  @doc """
  Gets a visible playground with its reviews (newest first), photos (oldest
  first) and validated details (newest first).

  Raises `Ecto.NoResultsError` if there is no such visible playground.
  """
  def get_visible_playground!(id) do
    reviews = from(r in Review, order_by: [desc: r.inserted_at, desc: r.id])
    photos = from(ph in Photo, order_by: [asc: ph.inserted_at, asc: ph.id])

    details =
      from(d in Detail,
        where: d.status == "validated",
        order_by: [desc: d.inserted_at, desc: d.id]
      )

    from(p in Playground,
      where: p.status == "visible",
      preload: [reviews: ^reviews, photos: ^photos, details: ^details]
    )
    |> Repo.get!(id)
  end

  @doc """
  Averages the surroundings and equipment ratings of `reviews`, ignoring
  missing ones. An average is `nil` when no review has that rating.
  """
  def average_ratings(reviews) do
    %{
      surroundings: average(reviews, :rating_surroundings),
      equipment: average(reviews, :rating_equipment)
    }
  end

  defp average(reviews, field) do
    case reviews |> Enum.map(&Map.get(&1, field)) |> Enum.reject(&is_nil/1) do
      [] -> nil
      ratings -> Enum.sum(ratings) / length(ratings)
    end
  end
end
