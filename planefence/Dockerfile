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

# Upstream bug: socket30003 restart loop has "|| true" after socket30003.pl which
# forces exitcode=0, so the 15s LOOPTIME sleep never fires when it crashes.
# exitcode="$?" is already on the next line — just strip the || true.
RUN sed -i '/socket30003\.pl.*&>\/dev\/null/ s/ || true//' \
    /etc/s6-overlay/scripts/socket30003