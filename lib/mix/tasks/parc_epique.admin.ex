defmodule Mix.Tasks.ParcEpique.Admin do
  @shortdoc "Grants or revokes the administrator role"

  @moduledoc """
  Grants the administrator role to the account with this email, or revokes
  it with `--revoke`. The account must exist (register on the site first).

      mix parc_epique.admin francis@example.com
      mix parc_epique.admin francis@example.com --revoke
  """
  use Mix.Task

  alias ParcEpique.Accounts

  @requirements ["app.start"]

  @impl true
  def run(args) do
    case OptionParser.parse(args, strict: [revoke: :boolean]) do
      {opts, [email], []} ->
        admin? = !opts[:revoke]

        case Accounts.get_user_by_email(email) do
          nil ->
            Mix.raise("No account with the email #{email}")

          user ->
            {:ok, _} = Accounts.set_admin(user, admin?)

            Mix.shell().info(
              "#{email} is #{if admin?, do: "now", else: "no longer"} an administrator"
            )
        end

      _ ->
        Mix.raise("Usage: mix parc_epique.admin EMAIL [--revoke]")
    end
  end
end
