# Parc Épique 2

Réécriture de [parc-epique.fr](https://parc-epique.fr) en Elixir (Phoenix 1.8, LiveView, PostgreSQL/PostGIS), auto-hébergée.

L'ancienne version (Vue.js 2 + Firebase) est dans [fchabouis/parc-epique](https://github.com/fchabouis/parc-epique). Le plan de travail est dans le jalon [V1 : parité avec l'ancien site](https://github.com/fchabouis/parc-epique-2/milestone/1).

## Lancer le projet en local

Prérequis : Elixir 1.18 / Erlang OTP 27, Docker.

```bash
docker compose up -d     # PostgreSQL + PostGIS sur le port 5432
mix setup                # dépendances, base de données, assets
mix phx.server           # http://localhost:4000 (redirige vers /fr)
```

Tests : `mix test`. Avant de pousser : `mix precommit`.

## Organisation

- Les routes publiques sont préfixées par la langue (`/fr/...`). Les langues disponibles sont listées dans `config/config.exs` (`ParcEpiqueWeb.Gettext`) ; les textes sont écrits en anglais dans le code (`gettext("...")`) et traduits dans `priv/gettext/<langue>/LC_MESSAGES/*.po` (`mix gettext.extract --merge` met les fichiers à jour).
- Les géométries utilisent PostGIS via `geo_postgis` (`ParcEpique.PostgrexTypes`).
- Les tâches de fond (miniatures, imports) passent par Oban.
- L'export des données Firebase est décrit dans `docs/firebase-export.md`.
