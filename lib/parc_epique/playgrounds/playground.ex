defmodule ParcEpique.Playgrounds.Playground do
  @moduledoc """
  A playground, imported from OpenStreetMap or added by a visitor.

  `legacy_key` is the key it had in Firebase (`node-123`, `way-123`,
  `aire-1515776975678`...), kept so the import can be re-run.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias ParcEpique.Playgrounds.{Detail, Photo, RemovalReport, Review}

  @osm_types ~w(node way relation)
  @sources ~w(osm user)
  @statuses ~w(visible pending hidden)

  schema "playgrounds" do
    field :osm_type, :string
    field :osm_id, :integer
    field :legacy_key, :string
    field :location, Geo.PostGIS.Geometry
    field :name, :string
    field :source, :string, default: "osm"
    field :status, :string, default: "visible"
    field :checked, :boolean, default: true
    field :legacy_author_uid, :string

    has_many :details, Detail
    has_many :reviews, Review
    has_many :photos, Photo
    has_many :removal_reports, RemovalReport

    belongs_to :user, ParcEpique.Accounts.User

    timestamps(type: :utc_datetime)
  end

  def changeset(playground, attrs) do
    playground
    |> cast(attrs, [
      :osm_type,
      :osm_id,
      :legacy_key,
      :location,
      :name,
      :source,
      :status,
      :checked,
      :legacy_author_uid,
      :user_id
    ])
    |> validate_required([:location, :source, :status])
    |> validate_inclusion(:osm_type, @osm_types)
    |> validate_inclusion(:source, @sources)
    |> validate_inclusion(:status, @statuses)
    |> validate_location()
    |> unique_constraint([:osm_type, :osm_id])
    |> unique_constraint(:legacy_key)
  end

  @doc "Builds a WGS 84 point from latitude and longitude."
  def point(lat, lon), do: %Geo.Point{coordinates: {lon, lat}, srid: 4326}

  defp validate_location(changeset) do
    validate_change(changeset, :location, fn :location, location ->
      case location do
        %Geo.Point{coordinates: {lon, lat}, srid: 4326}
        when lon >= -180 and lon <= 180 and lat >= -90 and lat <= 90 ->
          []

        _ ->
          [location: "must be a WGS 84 point"]
      end
    end)
  end
end
