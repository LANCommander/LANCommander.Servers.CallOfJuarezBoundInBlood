# syntax=docker/dockerfile:1.7

# Override to build against a locally built base, e.g. lancommander/wine:local
ARG BASE_IMAGE=lancommander/wine:latest
FROM ${BASE_IMAGE}

# ----------------------------
# Server settings
#   - The server is Techland's official Call of Juarez: Bound in Blood Dedicated Server 1.1.0.0
#     (CoJ_BiB_DedicatedServer_setup.exe, an Inno Setup installer). It can't be redistributed:
#     put the installer (or the zip it comes in) in /config, set COJBIB_INSTALLER_URL, or put an
#     installed copy in /config/Server. The install hook unpacks it with innoextract
#   - The COJBIB_* settings are written into CoJ2\DedicatedServerSettings.ini on every start,
#     unless COJBIB_MANAGE_CONFIG=false
#   - COJBIB_MODES: comma-separated, played in this order: deathmatch (Shootout), teamdeathmatch
#     (Posse), wanted (Wanted), teamwanted (Manhunt), historical (Wild West Legends)
#   - COJBIB_MAPS: comma-separated; empty = all eight: Adobes, Civil, Coffeyville, Frisco,
#     Magnificent, PrisonBreak2, StinkingSprings2, Tombstone
#   - The server is a GUI program and exits without a display, so it runs under Xvfb
# ----------------------------
ENV COJBIB_INSTALLER="" \
    COJBIB_INSTALLER_URL="" \
    COJBIB_MANAGE_CONFIG="true" \
    COJBIB_SERVER_NAME="LANCommander CoJ BiB" \
    COJBIB_SERVER_PASSWORD="" \
    COJBIB_PORT="27632" \
    COJBIB_INTERNET="false" \
    COJBIB_MAX_PLAYERS="12" \
    COJBIB_PLAYERS_TO_START="1" \
    COJBIB_FRIENDLY_FIRE="true" \
    COJBIB_MODES="deathmatch" \
    COJBIB_MAPS="" \
    COJBIB_TIME_LIMIT="" \
    COJBIB_BOUNTY_LIMIT="" \
    COJBIB_POINTS_LIMIT="" \
    COJBIB_ADMIN_LOGIN="" \
    COJBIB_ADMIN_PASSWORD="" \
    WINE_XVFB="true" \
    START_EXE="/usr/local/bin/cojbib-server" \
    START_ARGS=""

# innoextract unpacks the official Inno Setup installer without running it
RUN set -eux; \
    apt-get update; \
    apt-get install --no-install-recommends -y innoextract; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

COPY Scripts/cojbib-server /usr/local/bin/cojbib-server
RUN chmod +x /usr/local/bin/cojbib-server

COPY Hooks/ "${BASE_HOOKS}/"

# 27632/udp: game (COJBIB_PORT)
EXPOSE 27632/udp

WORKDIR /config
ENTRYPOINT ["/usr/local/bin/entrypoint.ps1"]
