# ============================================================
# Stage 1: Build
# ============================================================
FROM elixir:1.17-slim AS builder

# Install build dependencies
RUN apt-get update -y && apt-get install -y build-essential git curl \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*


# Prepare build dir
WORKDIR /app

# Install hex + rebar
RUN mix local.hex --force && \
    mix local.rebar --force

# Set build ENV
ENV MIX_ENV="prod"

# Install mix dependencies
COPY mix.exs mix.lock ./
RUN mix deps.get --only $MIX_ENV
RUN mkdir config

# Copy compile-time config files before we compile dependencies
# to ensure any relevant config change will trigger the dependencies
# to be re-compiled.
COPY config/config.exs config/${MIX_ENV}.exs config/
RUN mix deps.compile

# Copy application code
COPY priv priv
COPY lib lib
COPY assets assets

# Compile the project first (generates phoenix-colocated hooks in _build)
RUN mix compile

# Now compile assets (esbuild needs the colocated hooks from _build)
RUN mix assets.setup
RUN mix assets.deploy

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

# Copy release overlays
COPY rel rel

# Build the release
RUN mix release

# ============================================================
# Stage 2: Runtime (minimal image)
# ============================================================
FROM debian:bookworm-slim

RUN apt-get update -y && \
    apt-get install -y libstdc++6 openssl libncurses5 locales ca-certificates \
    && apt-get clean && rm -f /var/lib/apt/lists/*_*

# Set the locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen

ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

WORKDIR "/app"
RUN chown nobody /app

# Set runner ENV
ENV MIX_ENV="prod"
ENV PHX_SERVER="true"

# Only copy the final release from the build stage
COPY --from=builder --chown=nobody:root /app/_build/${MIX_ENV}/rel/perfi_delta ./

USER nobody

# If using an environment that doesn't automatically reap zombie processes,
# it is advised to add an init process such as tini via `apt-get install`
# above and adding an pointentry. See https://github.com/krallin/tini.
# ENTRYPOINT ["/tini", "--"]

CMD ["/app/bin/perfi_delta", "start"]
