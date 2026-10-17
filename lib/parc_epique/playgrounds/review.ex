defmodule ParcEpique.Playgrounds.Review do
  @moduledoc """
  A visitor's review: surroundings and equipment ratings (0 to 5, by half
  points) and an optional comment. One review per author and playground.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ParcEpique.Playgrounds.Playground

  schema "reviews" do
    field :rating_surroundings, :float
    field :rating_equipment, :float
    field :comment, :string
    field :display_name, :string
    field :legacy_author_uid, :string

    belongs_to :playground, Playground

    belongs_to :user, ParcEpique.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(review, attrs) do
    review
    |> cast(attrs, [
      :playground_id,
      :rating_surroundings,
      :rating_equipment,
      :comment,
      :display_name,
      :legacy_author_uid,
      :user_id
    ])
    |> validate_required([:playground_id])
    |> validate_rating(:rating_surroundings)
    |> validate_rating(:rating_equipment)
    |> validate_length(:comment, max: 5000)
    |> assoc_constraint(:playground)
    |> assoc_constraint(:user)
    |> unique_constraint([:playground_id, :legacy_author_uid])
    |> unique_constraint([:playground_id, :user_id])
  end

  defp validate_rating(changeset, field) do
    changeset
    |> validate_number(field, greater_than_or_equal_to: 0, less_than_or_equal_to: 5)
    |> validate_change(field, fn ^field, rating ->
      if rating * 2 == Float.round(rating * 2), do: [], else: [{field, "must be a half point"}]
    end)
  end
end
