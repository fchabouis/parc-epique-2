defmodule ParcEpiqueWeb.PageHTML do
  @moduledoc """
  Static pages: "About", with the origin of the data and how to reuse it.
  """
  use ParcEpiqueWeb, :html

  alias ParcEpiqueWeb.PlaygroundComponents

  @osm_copyright_url "https://www.openstreetmap.org/copyright"
  @odbl_url "https://opendatacommons.org/licenses/odbl/1-0/"
  @code_url "https://github.com/fchabouis/parc-epique-2"
  @article_url "https://medium.com/cr%C3%A9ation-dune-app-cartographique-avec-firebase-vue/cr%C3%A9ation-dune-app-cartographique-avec-firebase-vue-js-et-leaflet-868e9ea1b958"
  @facebook_url "https://www.facebook.com/ParcEpique/"

  def about(assigns) do
    assigns =
      assign(assigns,
        osm_copyright_url: @osm_copyright_url,
        odbl_url: @odbl_url,
        code_url: @code_url,
        article_url: @article_url,
        facebook_url: @facebook_url
      )

    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <article id="about" class="space-y-4 leading-relaxed">
        <h1 class="text-3xl font-semibold">{gettext("Children don't spend much time outdoors")}</h1>
        <p>{gettext("Have you heard of the \"Dirt is good\" campaign?")}</p>
        <p>
          {gettext(
            "A survey of 12,000 people in 10 countries shows that the time children spend outdoors is ridiculously low. A third of the children in the United Kingdom spend less than 30 minutes a day outside. On average, a child spends less time outdoors than a prisoner."
          )}
        </p>
        <p>
          {gettext(
            "It is true that the playground around the corner, as a parent, is a drag sometimes..."
          )}
        </p>

        <h2 class="pt-4 text-2xl font-semibold">{gettext("So...")}</h2>
        <p>
          {gettext(
            "This site lists the playgrounds, to push us parents to go out more often. And why not, to change playground from time to time."
          )}
        </p>

        <h2 class="pt-4 text-2xl font-semibold">{gettext("With your help")}</h2>
        <p>{gettext("Parc Épique is collaborative.")}</p>
        <p>
          {gettext(
            "The first list of playgrounds comes from OpenStreetMap, an open and collaborative mapping project. You can complete it by listing the equipment of a playground, giving your opinion on it and adding photos."
          )}
        </p>
        <p>
          {gettext(
            "The site is not commercial. It is meant to later help town halls hear about broken equipment and suggestions. By taking part you help everyone!"
          )}
        </p>

        <h2 id="data" class="pt-4 text-2xl font-semibold">{gettext("The data")}</h2>
        <p>
          {gettext(
            "The map shows data © OpenStreetMap contributors. The playground database, derived from OpenStreetMap, is shared under the Open Database Licence (ODbL): you may copy, use and adapt it, provided that you credit OpenStreetMap and Parc Épique and share what you build from it under the same licence."
          )}
        </p>
        <ul class="list-inside list-disc">
          <li>
            <a href={@osm_copyright_url} class="link" rel="noopener">
              {gettext("OpenStreetMap copyright")}
            </a>
          </li>
          <li>
            <a href={@odbl_url} class="link" rel="noopener">{gettext("Text of the ODbL")}</a>
          </li>
        </ul>
        <p>
          {gettext(
            "The export holds the position, the name, the validated details and the average ratings of each playground. It holds nothing about the people who contributed."
          )}
        </p>
        <p :if={@export_date} id="export">
          <a href={~p"/export/aires.geojson"} class="btn btn-primary btn-sm" download>
            {gettext("Download the playgrounds (GeoJSON)")}
          </a>
          <span class="text-sm opacity-70">
            {gettext("Updated on %{date}", date: PlaygroundComponents.format_date(@export_date))}
          </span>
        </p>
        <p :if={!@export_date} id="export" class="italic">
          {gettext("The export is generated every night. Come back tomorrow!")}
        </p>

        <h2 class="pt-4 text-2xl font-semibold">{gettext("FAQ")}</h2>
        <h3 class="pt-2 text-lg font-medium">{gettext("How can I take part?")}</h3>
        <p>
          {gettext(
            "You can take part without an account, or create one in a few seconds to find your contributions again from any device."
          )}
        </p>
        <h3 class="pt-2 text-lg font-medium">{gettext("Can I add a playground?")}</h3>
        <p>
          {gettext(
            "If a playground is missing from the map, right-click on the map (on a computer) or press and hold (on a phone or tablet)."
          )}
        </p>
        <h3 class="pt-2 text-lg font-medium">{gettext("Who made this?")}</h3>
        <p>
          {gettext(
            "Francis Chabouis. I am a freelance engineer and developer in Paris with a soft spot for maps."
          )}
        </p>
        <h3 class="pt-2 text-lg font-medium">
          {gettext("Can I have the technical details? I would like to do the same with bakeries...")}
        </h3>
        <p>
          {gettext(
            "The code of the project is free. I also wrote a technical article about the first version."
          )}
        </p>
        <ul class="list-inside list-disc">
          <li>
            <a href={@code_url} class="link" target="_blank" rel="noopener">
              {gettext("Source code on GitHub")}
            </a>
          </li>
          <li>
            <a href={@article_url} class="link" target="_blank" rel="noopener">
              {gettext("Technical article on Medium")}
            </a>
          </li>
        </ul>
        <h3 class="pt-2 text-lg font-medium">{gettext("A contact?")}</h3>
        <p>
          <a href={@facebook_url} class="link" target="_blank" rel="noopener">
            {gettext("To reach me, use the Parc Épique Facebook page")}
          </a>
        </p>
      </article>
    </Layouts.app>
    """
  end
end
