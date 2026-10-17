defmodule ParcEpique.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    create table(:users) do
      # Guests (contributors without an account) have no email, only the
      # SHA-256 of the random token kept in their session.
      add :email, :citext
      add :guest_token, :binary
      add :display_name, :string
      add :admin, :boolean, null: false, default: false
      add :hashed_password, :string
      add :confirmed_at, :naive_datetime

      timestamps()
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:guest_token])

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string
      add :authenticated_at, :naive_datetime

      timestamps(updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
