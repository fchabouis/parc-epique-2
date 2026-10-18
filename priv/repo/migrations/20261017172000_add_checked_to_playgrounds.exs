defmodule ParcEpique.Repo.Migrations.AddCheckedToPlaygrounds do
  use Ecto.Migration

  def change do
    # Playgrounds added from the site are unchecked until an administrator
    # looks at them; every existing playground counts as checked.
    alter table(:playgrounds) do
      add :checked, :boolean, null: false, default: true
    end

    create index(:playgrounds, [:id], where: "NOT checked", name: :playgrounds_unchecked_index)
  end
end
