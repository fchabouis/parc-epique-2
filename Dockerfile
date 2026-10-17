# Production image: Elixir release of the application.
#
#   docker build -t parc-epique .
#
# The build and the runtime use the same Debian-based image, so the release
# (which embeds Erlang) always finds the system libraries it was built with.
ARG ELIXIR_IMAGE=elixir:1.18.4-otp-27-slim

FROM ${ELIXIR_IMAGE} AS build

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends build-essential git curl ca-certificates \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /app
ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

# Dependencies first, so that they stay cached when only the code changes
COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mkdir config
COPY config/config.exs config/prod.exs config/
RUN mix deps.compile

COPY priv priv
COPY lib lib
COPY assets assets

RUN mix assets.setup
RUN mix compile
RUN mix assets.deploy

# Runtime configuration changes without recompiling
COPY config/runtime.exs config/
COPY rel rel
RUN mix release

FROM ${ELIXIR_IMAGE} AS app

RUN apt-get update -y \
  && apt-get install -y --no-install-recommends libstdc++6 openssl libncurses6 locales ca-certificates curl \
  && rm -rf /var/lib/apt/lists/* \
  && sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen \
  && locale-gen

ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# Photos and the public export live in a volume, owned by uid 1000
RUN useradd --uid 1000 --create-home app \
  && mkdir -p /data/uploads \
  && chown app /data/uploads
ENV UPLOADS_DIR=/data/uploads
VOLUME /data/uploads

WORKDIR /app
COPY --from=build --chown=app:app /app/_build/prod/rel/parc_epique ./
USER app

EXPOSE 4000
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
  CMD curl -fsS http://localhost:4000/health || exit 1

CMD ["/app/bin/server"]
