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

  @doc """
  A changeset for details proposed from the site: at least one piece of
  information is required. They stay pending until an administrator
  validates them.
  """
  def form_changeset(detail, attrs) do
    detail
    |> cast(attrs, [:equipment, :free, :open_at_night, :private])
    |> update_change(:equipment, fn equipment -> Enum.reject(equipment, &(&1 == "")) end)
    |> validate_subset(:equipment, Equipment.codes())
    |> validate_described()
  end

  defp validate_described(changeset) do
    described? =
      get_field(changeset, :equipment) != [] or
        Enum.any?([:free, :open_at_night, :private], &(not is_nil(get_field(changeset, &1))))

    if described?,
      do: changeset,
      else: add_error(changeset, :equipment, "tell us at least one thing")
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
