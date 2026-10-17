defmodule ParcEpique.Repo.Migrations.AddUserToContributions do
  use Ecto.Migration

  @tables [:playgrounds, :playground_details, :reviews, :photos, :removal_reports]

  def change do
    for table <- @tables do
      alter table(table) do
        add :user_id, references(:users, on_delete: :nilify_all)
      end

      create index(table, [:user_id])
    end

    create unique_index(:reviews, [:playground_id, :user_id], where: "user_id IS NOT NULL")
  end
end
