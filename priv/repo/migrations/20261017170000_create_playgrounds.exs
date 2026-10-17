defmodule ParcEpique.Repo.Migrations.CreatePlaygrounds do
  use Ecto.Migration

  def change do
    create table(:playgrounds) do
      add :osm_type, :string
      add :osm_id, :bigint
      add :legacy_key, :string
      add :location, :"geometry(Point, 4326)", null: false
      add :name, :string
      add :source, :string, null: false, default: "osm"
      add :status, :string, null: false, default: "visible"
      add :legacy_author_uid, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:playgrounds, [:osm_type, :osm_id], where: "osm_id IS NOT NULL")
    create unique_index(:playgrounds, [:legacy_key])
    create index(:playgrounds, [:location], using: :gist)

    create table(:playground_details) do
      add :playground_id, references(:playgrounds, on_delete: :delete_all), null: false
      add :equipment, {:array, :string}, null: false, default: []
      add :free, :boolean
      add :open_at_night, :boolean
      add :private, :boolean
      add :status, :string, null: false, default: "pending"
      add :legacy_key, :string
      add :legacy_author_uid, :string

      timestamps(type: :utc_datetime)
    end

    create index(:playground_details, [:playground_id])
    create unique_index(:playground_details, [:legacy_key])

    create table(:reviews) do
      add :playground_id, references(:playgrounds, on_delete: :delete_all), null: false
      add :rating_surroundings, :float
      add :rating_equipment, :float
      add :comment, :text
      add :display_name, :string
      add :legacy_author_uid, :string

      timestamps(type: :utc_datetime)
    end

    create index(:reviews, [:playground_id])
    create unique_index(:reviews, [:playground_id, :legacy_author_uid])

    create table(:photos) do
      add :playground_id, references(:playgrounds, on_delete: :delete_all), null: false
      add :path, :text, null: false
      add :thumbnail_path, :text
      add :verified, :boolean, null: false, default: false
      add :legacy_key, :string
      add :legacy_author_uid, :string

      timestamps(type: :utc_datetime)
    end

    create index(:photos, [:playground_id])
    create unique_index(:photos, [:legacy_key])

    create table(:removal_reports) do
      add :playground_id, references(:playgrounds, on_delete: :delete_all), null: false
      add :reason, :text
      add :status, :string, null: false, default: "pending"
      add :legacy_key, :string
      add :legacy_author_uid, :string

      timestamps(type: :utc_datetime)
    end

    create index(:removal_reports, [:playground_id])
    create unique_index(:removal_reports, [:legacy_key])
  end
end
