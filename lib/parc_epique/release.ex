defmodule ParcEpique.Release do
  @moduledoc """
  Tasks to run from a release, where Mix is not available:

      bin/parc_epique eval "ParcEpique.Release.migrate()"
      bin/parc_epique eval 'ParcEpique.Release.set_admin("me@example.com")'

  `bin/migrate` runs the migrations; the other tasks mirror the `mix
  parc_epique.*` tasks (`import_firebase`, `import_photos`, `export`, `admin`).
  """
  alias ParcEpique.Legacy.{FirebaseImport, PhotoImport}

  @app :parc_epique

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc "Imports the Firebase `database.json` export (safe to run again)."
  def import_firebase(path) do
    with_repo(fn ->
      {:ok, report} = FirebaseImport.run(path)
      IO.inspect(report, label: "Firebase import", limit: :infinity)
    end)
  end

  @doc "Copies the photos exported from Firebase Storage (after `import_firebase/1`)."
  def import_photos(dir) do
    with_repo(fn ->
      report = dir |> PhotoImport.run() |> Map.take([:imported, :thumbnails_generated])
      IO.inspect(report, label: "Photo import", limit: :infinity)
    end)
  end

  @doc "Generates the public GeoJSON export now."
  def export do
    with_repo(fn ->
      {:ok, count} = ParcEpique.Export.generate()
      IO.puts("#{count} playgrounds exported")
    end)
  end

  @doc "Grants the administrator role to the account with this email."
  def set_admin(email) do
    with_repo(fn ->
      case ParcEpique.Accounts.get_user_by_email(email) do
        nil ->
          IO.puts("No account with the email #{email}: sign up on the site first")

        user ->
          {:ok, _user} = ParcEpique.Accounts.set_admin(user, true)
          IO.puts("#{email} is now an administrator")
      end
    end)
  end

  defp with_repo(fun) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(ParcEpique.Repo, fn _repo -> fun.() end)
    :ok
  end

  defp repos, do: Application.fetch_env!(@app, :ecto_repos)

  defp load_app do
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
