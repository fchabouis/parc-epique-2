defmodule ParcEpique.Playgrounds.Photo do
  @moduledoc """
  A photo of a playground and its thumbnail. `path` and `thumbnail_path` are
  storage keys; photos stay unverified until an administrator checks them.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ParcEpique.Playgrounds.Playground

  schema "photos" do
    field :path, :string
    field :thumbnail_path, :string
    field :verified, :boolean, default: false
    field :legacy_key, :string
    field :legacy_author_uid, :string

    belongs_to :playground, Playground

    timestamps(type: :utc_datetime)
  end

  def changeset(photo, attrs) do
    photo
    |> cast(attrs, [
      :playground_id,
      :path,
      :thumbnail_path,
      :verified,
      :legacy_key,
      :legacy_author_uid
    ])
    |> validate_required([:playground_id, :path])
    |> assoc_constraint(:playground)
    |> unique_constraint(:legacy_key)
  end
end
