defmodule ParcEpique.Playgrounds do
  @moduledoc """
  Playgrounds and their contributions.
  """

  import Ecto.Query

  alias ParcEpique.Playgrounds.Playground
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
end
