defmodule ParcEpique.Playgrounds.RemovalReport do
  @moduledoc """
  A visitor's report that a playground no longer exists.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ParcEpique.Playgrounds.Playground

  @statuses ~w(pending accepted rejected)

  schema "removal_reports" do
    field :reason, :string
    field :status, :string, default: "pending"
    field :legacy_key, :string
    field :legacy_author_uid, :string

    belongs_to :playground, Playground

    belongs_to :user, ParcEpique.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(report, attrs) do
    report
    |> cast(attrs, [:playground_id, :reason, :status, :legacy_key, :legacy_author_uid, :user_id])
    |> validate_required([:playground_id, :status])
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:reason, max: 2000)
    |> assoc_constraint(:playground)
    |> unique_constraint(:legacy_key)
  end
end
