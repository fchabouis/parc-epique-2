defmodule ParcEpique.Repo do
  use Ecto.Repo,
    otp_app: :parc_epique,
    adapter: Ecto.Adapters.Postgres
end
