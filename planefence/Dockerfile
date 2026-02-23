ARG BUILD_FROM=ghcr.io/sdr-enthusiasts/docker-planefence:latest-build-1162
FROM $BUILD_FROM

ENV TZ=UTC

# Add curl, jq, bc for HA Supervisor API calls
RUN apt-get update && apt-get install -y curl jq bc \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Add cont-init.d script to generate planefence.config from HA options.
# Planefence reads all its config from planefence.config, so we don't
# need to inject env vars into s6 scripts.
COPY export-env-from-config.sh /export-env-from-config.sh
COPY rootfs /
RUN chmod +x /etc/cont-init.d/00-ha-planefence-config.sh

# Replace planefence's ephemeral persist dir with a symlink to /config/planefence
# at build time so all s6 services see the correct path from the very first moment.
# Save the upstream template first so cont-init.d can copy it on first start.
RUN cp /usr/share/planefence/stage/persist/planefence.config.RENAME-and-EDIT-me \
    /planefence.config.template \
    && mkdir -p /var/lib/planefence-persist/.internal \
    # Do NOT pre-create planefence.config here. Leaving it absent means
    # socket30003's own native wait loop blocks until cont-init.d writes
    # the real config from options.json - with the correct host/coords already merged.
    # A pre-baked stub would have PF_SOCK30003HOST=ultrafeeder and bypass that wait.
    && rm -rf /usr/share/planefence/persist \
    && ln -sf /var/lib/planefence-persist /usr/share/planefence/persist

# Ensure 00-container-startup waits for our cont-init.d to finish writing the
# real config before prep-planefence.sh and socket30003 read it.
# After the wait, source planefence.config immediately so all ${:-default}
# expansions in the startup script see the real values.
RUN sed -i \
    -e '1a # Wait for HA addon cont-init.d to write the real planefence.config' \
    -e '1a while [[ ! -f /run/ha-planefence-ready ]]; do sleep 0.2; done' \
    -e '1a set -o allexport 2>/dev/null; source /usr/share/planefence/persist/planefence.config 2>/dev/null || true; set +o allexport 2>/dev/null' \
    /etc/s6-overlay/scripts/00-container-startup

# Upstream bug: pkill socket30003.pl returns exit code 1 when the process
# isn't running yet (first start), which kills the script under set -eo pipefail.
RUN sed -i 's/pkill socket30003\.pl$/pkill socket30003.pl || true/' \
    /usr/share/planefence/prep-planefence.sh

# Upstream bug: SQUAWKS[-1] on an empty array causes "bad array subscript"
# when plane-alert.conf has no SQUAWKS line matching the sed pattern.
# Guard the array access so it's skipped when the array is empty.
RUN sed -i \
    's|^SQUAWKS\[-1\]=.*|[[ ${#SQUAWKS[@]} -gt 0 ]] \&\& SQUAWKS[-1]="${SQUAWKS[-1]%$'"'"'\\n'"'"'}"|' \
    /usr/share/planefence/pf-process_sbs.sh

# socket30003 is an independent s6 service. It sets HOST="${PF_SOCK30003HOST:-ultrafeeder}"
# before sourcing planefence.config, so the env captured by with-contenv at process
# start wins. Fix: wait for cont-init.d, then immediately source planefence.config
# so PF_SOCK30003HOST is loaded from disk before any ${:-default} is evaluated.
RUN sed -i \
    -e '1a # Wait for HA addon cont-init.d to write the real planefence.config' \
    -e '1a while [[ ! -f /run/ha-planefence-ready ]]; do sleep 0.2; done' \
    -e '1a # Source it immediately so PF_SOCK30003HOST is set before ${:-ultrafeeder} runs' \
    -e '1a set -o allexport 2>/dev/null; source /usr/share/planefence/persist/planefence.config 2>/dev/null || true; set +o allexport 2>/dev/null' \
    /etc/s6-overlay/scripts/socket30003

# Upstream bug: socket30003 restart loop has "|| true" after socket30003.pl which
# forces exitcode=0, so the 15s LOOPTIME sleep never fires when it crashes.
# exitcode="$?" is already on the next line — just strip the || true.
RUN sed -i '/socket30003\.pl.*&>\/dev\/null/ s/ || true//' \
    /etc/s6-overlay/scripts/socket30003

# Diagnostic: show the first 20 lines of the patched socket30003 script
# and list all socket30003-related files to verify our patches landed correctly.
RUN echo "=== PATCHED socket30003 (first 20 lines) ===" \
    && head -20 /etc/s6-overlay/scripts/socket30003 \
    && echo "=== ALL socket30003 files ===" \
    && find / -name "socket30003*" -not -path "/proc/*" 2>/dev/null