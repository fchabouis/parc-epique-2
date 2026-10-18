defmodule ParcEpique.Playgrounds do
  @moduledoc """
  Playgrounds and their contributions.
  """

  import Ecto.Query

  alias ParcEpique.Playgrounds.{Detail, Photo, Playground, RemovalReport, Review}
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

  @doc """
  Gets `user`'s review of the playground, if any.
  """
  def get_review(playground_id, user_id) do
    Repo.get_by(Review, playground_id: playground_id, user_id: user_id)
  end

  @doc """
  Returns a changeset for the review form; `review` is the user's existing
  review or a new one.
  """
  def change_review(%Review{} = review, attrs \\ %{}) do
    Review.form_changeset(review, attrs)
  end

  @doc """
  Saves `user`'s review of the playground: there is one review per user and
  playground, so posting again updates it. The review keeps the user's
  display name of the moment.
  """
  def save_review(%Playground{} = playground, %ParcEpique.Accounts.User{} = user, attrs) do
    review =
      get_review(playground.id, user.id) ||
        %Review{playground_id: playground.id, user_id: user.id}

    review
    |> Review.form_changeset(attrs)
    |> Ecto.Changeset.put_change(:display_name, user.display_name)
    |> Repo.insert_or_update()
  end

  @doc """
  Adds a playground placed on the map by `user` (a guest or an account). It
  is visible right away and listed in the moderation, as `source: "user"`.
  """
  def add_playground(%ParcEpique.Accounts.User{} = user, lat, lng)
      when is_number(lat) and is_number(lng) do
    %Playground{}
    |> Playground.changeset(%{
      location: Playground.point(lat * 1.0, lng * 1.0),
      source: "user",
      status: "visible",
      checked: false,
      user_id: user.id
    })
    |> Repo.insert()
  end

  @doc """
  Returns a changeset for the details form.
  """
  def change_detail(%Detail{} = detail, attrs \\ %{}), do: Detail.form_changeset(detail, attrs)

  @doc """
  Records details proposed by `user` for a playground. They are pending
  until an administrator validates them.
  """
  def propose_details(%Playground{} = playground, %ParcEpique.Accounts.User{} = user, attrs) do
    %Detail{playground_id: playground.id, user_id: user.id, status: "pending"}
    |> Detail.form_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Records `user`'s report that a playground no longer exists, for the
  moderation. A user's second report of the same playground is ignored.
  """
  def report_removal(
        %Playground{} = playground,
        %ParcEpique.Accounts.User{} = user,
        reason \\ nil
      ) do
    case Repo.get_by(RemovalReport,
           playground_id: playground.id,
           user_id: user.id,
           status: "pending"
         ) do
      nil ->
        %RemovalReport{playground_id: playground.id, user_id: user.id}
        |> RemovalReport.changeset(%{reason: reason})
        |> Repo.insert()

      report ->
        {:ok, report}
    end
  end

  @doc """
  Stores an uploaded image file as a photo of the playground and queues its
  thumbnail. The photo is unverified until an administrator checks it and is
  shown meanwhile, as on the old site.

  Returns `{:error, :unsupported}` when the file is not an image.
  """
  def add_photo(%Playground{} = playground, %ParcEpique.Accounts.User{} = user, source_path) do
    case ParcEpique.Media.extension(source_path) do
      nil ->
        {:error, :unsupported}

      extension ->
        key = "photos/#{playground.id}/#{Ecto.UUID.generate()}#{extension}"

        with :ok <- ParcEpique.Storage.put_file(source_path, key),
             {:ok, photo} <-
               %Photo{playground_id: playground.id, user_id: user.id, path: key, verified: false}
               |> Photo.changeset(%{})
               |> Repo.insert(),
             {:ok, _job} <- ParcEpique.Workers.GenerateThumbnail.enqueue(photo) do
          {:ok, photo}
        end
    end
  end
end
