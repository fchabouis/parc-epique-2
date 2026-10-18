defmodule ParcEpiqueWeb.AdminLive.Moderation do
  @moduledoc """
  Moderation of the contributions of visitors, for administrators
  (see `ParcEpique.Moderation`). One tab per kind of contribution, plus the
  feed of the latest ones.
  """
  use ParcEpiqueWeb, :live_view

  alias ParcEpique.Moderation
  alias ParcEpique.Storage
  alias ParcEpiqueWeb.PlaygroundComponents

  @actions %{
    "check_playground" => &Moderation.check_playground/1,
    "hide_playground" => &Moderation.hide_playground/1,
    "validate_detail" => &Moderation.validate_detail/1,
    "reject_detail" => &Moderation.reject_detail/1,
    "verify_photo" => &Moderation.verify_photo/1,
    "delete_photo" => &Moderation.delete_photo/1,
    "accept_report" => &Moderation.accept_report/1,
    "reject_report" => &Moderation.reject_report/1,
    "delete_review" => &Moderation.delete_review/1
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: gettext("Moderation"))}
  end

  @impl true
  def handle_params(_params, _uri, socket) do
    {:noreply, load(socket)}
  end

  @impl true
  def handle_event("moderate", %{"action" => action, "id" => id}, socket) do
    with {:ok, fun} <- Map.fetch(@actions, action),
         {id, ""} <- Integer.parse(id) do
      # An item that is gone was handled by someone else: the list is reloaded.
      _ = fun.(id)
    end

    {:noreply, load(socket)}
  end

  defp load(socket) do
    tab = socket.assigns.live_action

    socket
    |> assign(tab: tab, counts: Moderation.counts())
    |> assign(items: items(tab))
  end

  defp items(:feed), do: Moderation.recent_contributions()
  defp items(:playgrounds), do: Moderation.list_unchecked_playgrounds()
  defp items(:details), do: Moderation.list_pending_details()
  defp items(:photos), do: Moderation.list_unverified_photos()
  defp items(:reports), do: Moderation.list_pending_reports()
  defp items(:reviews), do: Moderation.list_recent_reviews()

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} wide>
      <div class="mx-auto max-w-4xl space-y-6 px-4 py-6">
        <h1 class="text-2xl font-semibold">{gettext("Moderation")}</h1>

        <nav id="moderation-tabs" class="tabs tabs-border overflow-x-auto">
          <.link
            :for={tab <- [:feed, :playgrounds, :details, :photos, :reports, :reviews]}
            id={"tab-#{tab}"}
            patch={tab_path(@locale, tab)}
            class={["tab whitespace-nowrap", @tab == tab && "tab-active"]}
          >
            {tab_label(tab)}
            <span :if={Map.get(@counts, tab, 0) > 0} class="badge badge-primary badge-sm ml-2">
              {Map.get(@counts, tab)}
            </span>
          </.link>
        </nav>

        <p :if={@items == []} id="nothing-to-moderate" class="italic">
          {gettext("Nothing here.")}
        </p>

        <ul :if={@tab == :feed} id="feed" class="space-y-2">
          <li :for={item <- @items} class="flex flex-wrap items-baseline gap-x-2">
            <span class="badge badge-ghost">{feed_label(item.kind)}</span>
            <.playground_link locale={@locale} id={item.playground_id} />
            <span class="text-sm opacity-70">
              {gettext("by %{author}, %{date}",
                author: author_name(item.author),
                date: PlaygroundComponents.format_date(item.at)
              )}
            </span>
          </li>
        </ul>

        <div :if={@tab == :playgrounds} id="playgrounds" class="space-y-3">
          <.card :for={playground <- @items} id={"playground-#{playground.id}"}>
            <p>
              <.playground_link locale={@locale} id={playground.id} />
              <span class="text-sm opacity-70">
                {Float.round(PlaygroundComponents.lat(playground), 5)}, {Float.round(
                  PlaygroundComponents.lng(playground),
                  5
                )}
              </span>
            </p>
            <.byline author={playground.user} at={playground.inserted_at} />
            <:actions>
              <.action action="check_playground" id={playground.id} kind="primary">
                {gettext("Keep")}
              </.action>
              <.action
                action="hide_playground"
                id={playground.id}
                confirm={gettext("Hide this playground from the map?")}
              >
                {gettext("Hide")}
              </.action>
            </:actions>
          </.card>
        </div>

        <div :if={@tab == :details} id="details" class="space-y-3">
          <.card :for={detail <- @items} id={"detail-#{detail.id}"}>
            <p><.playground_link locale={@locale} id={detail.playground_id} /></p>
            <PlaygroundComponents.detail_facts detail={detail} />
            <.byline author={detail.user} at={detail.inserted_at} />
            <:actions>
              <.action action="validate_detail" id={detail.id} kind="primary">
                {gettext("Validate")}
              </.action>
              <.action action="reject_detail" id={detail.id}>{gettext("Reject")}</.action>
            </:actions>
          </.card>
        </div>

        <div :if={@tab == :photos} id="photos" class="grid gap-3 sm:grid-cols-2">
          <.card :for={photo <- @items} id={"photo-#{photo.id}"}>
            <p><.playground_link locale={@locale} id={photo.playground_id} /></p>
            <a href={photo_url(photo)} target="_blank" rel="noopener">
              <img
                src={photo_url(photo, :thumbnail)}
                alt=""
                loading="lazy"
                class="max-h-64 rounded"
              />
            </a>
            <.byline author={photo.user} at={photo.inserted_at} />
            <:actions>
              <.action action="verify_photo" id={photo.id} kind="primary">
                {gettext("Validate")}
              </.action>
              <.action
                action="delete_photo"
                id={photo.id}
                confirm={gettext("Delete this photo for good?")}
              >
                {gettext("Delete")}
              </.action>
            </:actions>
          </.card>
        </div>

        <div :if={@tab == :reports} id="reports" class="space-y-3">
          <.card :for={report <- @items} id={"report-#{report.id}"}>
            <p>
              <.playground_link locale={@locale} id={report.playground_id} />
              <span class="text-sm opacity-70">
                {gettext("is reported as no longer existing")}
              </span>
            </p>
            <p :if={report.reason} class="italic">{report.reason}</p>
            <.byline author={report.user} at={report.inserted_at} />
            <:actions>
              <.action
                action="accept_report"
                id={report.id}
                kind="primary"
                confirm={gettext("Hide this playground from the map?")}
              >
                {gettext("Hide the playground")}
              </.action>
              <.action action="reject_report" id={report.id}>
                {gettext("Dismiss the report")}
              </.action>
            </:actions>
          </.card>
        </div>

        <div :if={@tab == :reviews} id="reviews" class="space-y-3">
          <.card :for={review <- @items} id={"review-#{review.id}"}>
            <p><.playground_link locale={@locale} id={review.playground_id} /></p>
            <p class="text-sm">
              {gettext("Surroundings: %{surroundings}, equipment: %{equipment}",
                surroundings: review.rating_surroundings || "-",
                equipment: review.rating_equipment || "-"
              )}
            </p>
            <p :if={review.comment} class="whitespace-pre-line">{review.comment}</p>
            <.byline author={review.user} at={review.inserted_at} />
            <:actions>
              <.action
                action="delete_review"
                id={review.id}
                confirm={gettext("Delete this review for good?")}
              >
                {gettext("Delete")}
              </.action>
            </:actions>
          </.card>
        </div>
      </div>
    </Layouts.app>
    """
  end

  attr :id, :string, required: true
  slot :inner_block, required: true
  slot :actions

  defp card(assigns) do
    ~H"""
    <article id={@id} class="card card-border bg-base-100">
      <div class="card-body gap-2 p-4">
        {render_slot(@inner_block)}
        <div class="card-actions">{render_slot(@actions)}</div>
      </div>
    </article>
    """
  end

  attr :action, :string, required: true
  attr :id, :integer, required: true
  attr :kind, :string, default: nil
  attr :confirm, :string, default: nil
  slot :inner_block, required: true

  defp action(assigns) do
    ~H"""
    <button
      type="button"
      class={["btn btn-sm", @kind == "primary" && "btn-primary"]}
      phx-click="moderate"
      phx-value-action={@action}
      phx-value-id={@id}
      data-confirm={@confirm}
    >
      {render_slot(@inner_block)}
    </button>
    """
  end

  attr :locale, :string, required: true
  attr :id, :integer, required: true

  defp playground_link(assigns) do
    ~H"""
    <.link navigate={~p"/#{@locale}/aires/#{@id}"} class="link font-medium">
      {gettext("Playground #%{id}", id: @id)}
    </.link>
    """
  end

  attr :author, :any, default: nil
  attr :at, :any, required: true

  defp byline(assigns) do
    ~H"""
    <p class="text-sm opacity-70">
      {gettext("by %{author}, %{date}",
        author: author_name(@author),
        date: PlaygroundComponents.format_date(@at)
      )}
    </p>
    """
  end

  defp author_name(%{display_name: name}) when is_binary(name) and name != "", do: name
  defp author_name(%{email: email}) when is_binary(email), do: email
  defp author_name(_author), do: gettext("a visitor")

  defp photo_url(photo, :thumbnail), do: Storage.url(photo.thumbnail_path || photo.path)
  defp photo_url(photo), do: Storage.url(photo.path)

  defp tab_path(locale, :feed), do: ~p"/#{locale}/admin"
  defp tab_path(locale, :playgrounds), do: ~p"/#{locale}/admin/aires"
  defp tab_path(locale, :details), do: ~p"/#{locale}/admin/details"
  defp tab_path(locale, :photos), do: ~p"/#{locale}/admin/photos"
  defp tab_path(locale, :reports), do: ~p"/#{locale}/admin/signalements"
  defp tab_path(locale, :reviews), do: ~p"/#{locale}/admin/avis"

  defp tab_label(:feed), do: gettext("Latest")
  defp tab_label(:playgrounds), do: gettext("New playgrounds")
  defp tab_label(:details), do: gettext("Details")
  defp tab_label(:photos), do: gettext("Photos")
  defp tab_label(:reports), do: gettext("Reports")
  defp tab_label(:reviews), do: gettext("Reviews")

  defp feed_label(:playground), do: gettext("New playground")
  defp feed_label(:detail), do: gettext("Details")
  defp feed_label(:photo), do: gettext("Photo")
  defp feed_label(:report), do: gettext("Report")
  defp feed_label(:review), do: gettext("Review")
end
