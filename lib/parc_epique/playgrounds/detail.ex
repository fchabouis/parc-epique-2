defmodule ParcEpique.Playgrounds.Detail do
  @moduledoc """
  Details proposed for a playground (equipment, free, open at night, private).

  Visitors propose them and an administrator validates them.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ParcEpique.Playgrounds.{Equipment, Playground}

  @statuses ~w(pending validated rejected)

  schema "playground_details" do
    field :equipment, {:array, :string}, default: []
    field :free, :boolean
    field :open_at_night, :boolean
    field :private, :boolean
    field :status, :string, default: "pending"
    field :legacy_key, :string
    field :legacy_author_uid, :string

    belongs_to :playground, Playground

    belongs_to :user, ParcEpique.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(detail, attrs) do
    detail
    |> cast(attrs, [
      :playground_id,
      :equipment,
      :free,
      :open_at_night,
      :private,
      :status,
      :legacy_key,
      :legacy_author_uid,
      :user_id
    ])
    |> validate_required([:playground_id, :status])
    |> validate_subset(:equipment, Equipment.codes())
    |> validate_inclusion(:status, @statuses)
    |> assoc_constraint(:playground)
    |> unique_constraint(:legacy_key)
  end
end
