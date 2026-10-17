defmodule ParcEpique.Accounts.ContributorsTest do
  use ParcEpique.DataCase, async: true

  import ParcEpique.AccountsFixtures

  alias ParcEpique.Accounts
  alias ParcEpique.Accounts.{Scope, User}
  alias ParcEpique.Playgrounds.{Photo, Playground, Review}

  defp playground do
    Repo.insert!(Playground.changeset(%Playground{}, %{location: Playground.point(48.84, 2.35)}))
  end

  defp review(playground, user, comment) do
    Repo.insert!(%Review{playground_id: playground.id, user_id: user.id, comment: comment})
  end

  describe "guests" do
    test "a guest user is created once per token" do
      token = Accounts.generate_guest_token()

      assert %User{id: id, email: nil} = Accounts.get_or_create_guest_user(token)
      assert %User{id: ^id} = Accounts.get_or_create_guest_user(token)
      assert %User{id: ^id} = Accounts.get_guest_user(token)
      refute Accounts.get_guest_user(Accounts.generate_guest_token())
    end

    test "the token is not stored in clear" do
      token = Accounts.generate_guest_token()
      guest = Accounts.get_or_create_guest_user(token)
      refute guest.guest_token == token
    end

    test "merging moves the guest's contributions to the account" do
      token = Accounts.generate_guest_token()
      guest = Accounts.get_or_create_guest_user(token)
      user = user_fixture()
      both = playground()
      only_guest = playground()

      review(both, user, "older")
      review(both, guest, "newer")
      review(only_guest, guest, "guest")
      photo = Repo.insert!(%Photo{playground_id: both.id, path: "p.jpg", user_id: guest.id})

      assert {:ok, %User{}} = Accounts.merge_guest_user(token, user)

      assert Repo.all(from r in Review, where: r.user_id == ^user.id, select: r.comment)
             |> Enum.sort() == ["guest", "newer"]

      assert Repo.reload!(photo).user_id == user.id
      refute Repo.get(User, guest.id)
    end

    test "merging without a guest does nothing" do
      assert {:ok, nil} =
               Accounts.merge_guest_user(Accounts.generate_guest_token(), user_fixture())
    end
  end

  describe "get_or_register_verified_user/1" do
    test "registers a confirmed account" do
      assert {:ok, %User{confirmed_at: %NaiveDateTime{}} = user} =
               Accounts.get_or_register_verified_user("new@example.com")

      assert user.email == "new@example.com"
    end

    test "confirms an existing account" do
      user = unconfirmed_user_fixture()

      assert {:ok, %User{id: id, confirmed_at: %NaiveDateTime{}}} =
               Accounts.get_or_register_verified_user(user.email)

      assert id == user.id
    end
  end

  test "registers a display name" do
    assert {:ok, user} =
             Accounts.register_user(%{email: unique_user_email(), display_name: "  Camille "})

    assert user.display_name == "Camille"
  end

  test "grants and revokes the administrator role" do
    user = user_fixture()
    refute Scope.admin?(Scope.for_user(user))

    {:ok, admin} = Accounts.set_admin(user, true)
    assert Scope.admin?(Scope.for_user(admin))

    {:ok, user} = Accounts.set_admin(admin, false)
    refute Scope.admin?(Scope.for_user(user))
  end
end
