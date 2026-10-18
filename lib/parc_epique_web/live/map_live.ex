defmodule ParcEpiqueWeb.MapLive do
  @moduledoc """
  Home page: the map of playgrounds.

  The `Map` JS hook (assets/js/hooks/map.js) sends the visible bounds with a
  "bounds" event; the playgrounds inside are pushed back as "playgrounds".

  At `/:locale/aires/:id` the playground sheet is open next to the map. It is
  part of the server-rendered page, so each playground has a URL that can be
  shared and crawled. Clicking a marker sends "open", which patches the URL.
  """
  use ParcEpiqueWeb, :live_view

  alias ParcEpique.{Accounts, Playgrounds}
  alias ParcEpique.Playgrounds.Review
  alias ParcEpiqueWeb.PlaygroundComponents

  @limit 3000

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, truncated: false, photo: nil, review_form: nil, register_prompt: false)}
  end

  @impl true
  def handle_params(%{"id" => id}, _uri, socket) do
    playground = Playgrounds.get_visible_playground!(parse_id!(id))

    {:noreply,
     socket
     |> assign(
       playground: playground,
       ratings: Playgrounds.average_ratings(playground.reviews),
       photo: nil,
       review_form: nil,
       register_prompt: false,
       page_title: PlaygroundComponents.playground_name(playground)
     )
     |> push_event("focus", %{
       id: playground.id,
       lat: PlaygroundComponents.lat(playground),
       lng: PlaygroundComponents.lng(playground)
     })}
  end

  def handle_params(_params, _uri, socket) do
    {:noreply, assign(socket, playground: nil, photo: nil, page_title: gettext("Playground map"))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} wide>
      <div class="relative flex h-[calc(100dvh-4rem)]">
        <div
          id="map"
          phx-hook="Map"
          phx-update="ignore"
          data-style-url={Application.fetch_env!(:parc_epique, :map_style_url)}
          data-locate-label={gettext("Show my position")}
          data-add-labels={
            Jason.encode!(%{
              hint: gettext("Move the marker to the playground, then save it."),
              save: gettext("Add this playground"),
              remove: gettext("Remove the marker"),
              back: gettext("Back to the map")
            })
          }
          data-focus-lat={@playground && PlaygroundComponents.lat(@playground)}
          data-focus-lng={@playground && PlaygroundComponents.lng(@playground)}
          class="h-full min-w-0 flex-1"
        >
        </div>
        <p
          :if={@truncated}
          class="absolute bottom-6 left-1/2 z-[1000] -translate-x-1/2 rounded-full bg-base-100 px-4 py-2 text-sm shadow"
        >
          {gettext("Zoom in to see all the playgrounds")}
        </p>
        <aside
          :if={@playground}
          id="playground-sheet"
          class="absolute inset-x-0 bottom-0 z-[1000] max-h-[60%] overflow-y-auto rounded-t-2xl bg-base-100 shadow-xl md:static md:max-h-none md:w-[28rem] md:shrink-0 md:rounded-none md:border-l md:border-base-300 md:shadow-none"
        >
          <PlaygroundComponents.playground_sheet
            playground={@playground}
            ratings={@ratings}
            close={~p"/#{@locale}"}
            review_form={@review_form}
            register_prompt={@register_prompt}
          />
        </aside>
      </div>
      <PlaygroundComponents.photo_modal :if={@photo} photo={@photo} />
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("bounds", params, socket) do
    case parse_bounds(params) do
      {:ok, bounds} ->
        {playgrounds, truncated} = Playgrounds.list_in_bounds(bounds, limit: @limit)

        {:noreply,
         socket
         |> assign(truncated: truncated)
         |> push_event("playgrounds", %{playgrounds: Enum.map(playgrounds, &marker/1)})}

      :error ->
        {:noreply, socket}
    end
  end

  def handle_event("add_playground", %{"lat" => lat, "lng" => lng}, socket)
      when is_number(lat) and is_number(lng) do
    {user, _guest?} = contributor!(socket)

    case Playgrounds.add_playground(user, lat, lng) do
      {:ok, playground} ->
        new_marker =
          marker(%{id: playground.id, name: nil, reviewed: false, location: playground.location})

        {:noreply,
         socket
         |> push_event("playgrounds", %{playgrounds: [new_marker]})
         |> put_flash(:info, gettext("The playground has been added, thank you!"))
         |> push_patch(to: ~p"/#{socket.assigns.locale}/aires/#{playground.id}")}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, gettext("The playground could not be added."))}
    end
  end

  def handle_event("open", %{"id" => id}, socket) when is_integer(id) do
    {:noreply, push_patch(socket, to: ~p"/#{socket.assigns.locale}/aires/#{id}")}
  end

  def handle_event("show_photo", %{"id" => id}, %{assigns: %{playground: %{} = p}} = socket) do
    {:noreply, assign(socket, photo: Enum.find(p.photos, &(to_string(&1.id) == id)))}
  end

  def handle_event("show_photo", _params, socket), do: {:noreply, socket}

  def handle_event("hide_photo", _params, socket) do
    {:noreply, assign(socket, photo: nil)}
  end

  def handle_event("new_review", _params, %{assigns: %{playground: %{} = playground}} = socket) do
    review =
      case current_contributor(socket) do
        nil -> nil
        user -> Playgrounds.get_review(playground.id, user.id)
      end

    form = review |> Kernel.||(%Review{}) |> Playgrounds.change_review() |> to_form()
    {:noreply, assign(socket, review_form: form, register_prompt: false)}
  end

  def handle_event("cancel_review", _params, socket) do
    {:noreply, assign(socket, review_form: nil)}
  end

  def handle_event("validate_review", %{"review" => params}, socket) do
    changeset = %Review{} |> Playgrounds.change_review(params) |> Map.put(:action, :validate)
    {:noreply, assign(socket, review_form: to_form(changeset))}
  end

  def handle_event(
        "save_review",
        %{"review" => params},
        %{assigns: %{playground: %{} = p}} = socket
      ) do
    {user, guest?} = contributor!(socket)

    case Playgrounds.save_review(p, user, params) do
      {:ok, _review} ->
        playground = Playgrounds.get_visible_playground!(p.id)

        {:noreply,
         socket
         |> assign(
           playground: playground,
           ratings: Playgrounds.average_ratings(playground.reviews),
           review_form: nil,
           register_prompt: guest?
         )
         |> put_flash(:info, gettext("Thank you for your review!"))
         |> push_event("reviewed", %{id: playground.id})}

      {:error, changeset} ->
        {:noreply, assign(socket, review_form: to_form(changeset))}
    end
  end

  defp marker(%{
         id: id,
         name: name,
         reviewed: reviewed,
         location: %Geo.Point{coordinates: {lng, lat}}
       }) do
    %{id: id, lat: lat, lng: lng, name: name || gettext("Playground"), reviewed: reviewed}
  end

  @doc false
  def parse_bounds(%{"south" => s, "west" => w, "north" => n, "east" => e})
      when is_number(s) and is_number(w) and is_number(n) and is_number(e) do
    {:ok,
     %{
       south: clamp(s, -90, 90),
       north: clamp(n, -90, 90),
       west: clamp(w, -180, 180),
       east: clamp(e, -180, 180)
     }}
  end

  def parse_bounds(_params), do: :error

  # The signed-in user, or the guest of this session if they already contributed.
  defp current_contributor(%{assigns: %{current_scope: %{user: %{} = user}}}), do: user

  defp current_contributor(%{assigns: %{guest_token: token}}) when is_binary(token),
    do: Accounts.get_guest_user(token)

  defp current_contributor(_socket), do: nil

  # The signed-in user, or the guest of this session, created if needed;
  # with whether it is a guest.
  defp contributor!(%{assigns: %{current_scope: %{user: %{} = user}}}), do: {user, false}

  defp contributor!(%{assigns: %{guest_token: token}}) when is_binary(token),
    do: {Accounts.get_or_create_guest_user(token), true}

  defp parse_id!(id) do
    case Integer.parse(id) do
      {id, ""} when id > 0 -> id
      _ -> raise Ecto.NoResultsError, queryable: ParcEpique.Playgrounds.Playground
    end
  end

  defp clamp(value, lo, hi), do: value |> max(lo) |> min(hi) |> Kernel.*(1.0)
end
