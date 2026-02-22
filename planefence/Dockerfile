ARG BUILD_FROM=ghcr.io/sdr-enthusiasts/docker-planefence:latest-build-1162
FROM $BUILD_FROM

ENV TZ=UTC

# Add bashio for Home Assistant integration
ADD https://github.com/hassio-addons/bashio/archive/v0.15.0.tar.gz /tmp/bashio.tar.gz
RUN apt-get update && apt-get install -y curl jq bc \
    && mkdir /tmp/bashio \
    && tar zxvf /tmp/bashio.tar.gz --strip 1 -C /tmp/bashio \
    && mv /tmp/bashio/lib /usr/lib/bashio \
    && ln -s /usr/lib/bashio/bashio /usr/bin/bashio \
    && rm -rf /tmp/bashio.tar.gz /tmp/bashio \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Add HA options.json → environment variable helper
COPY export-env-from-config.sh /export-env-from-config.sh
RUN chmod +x /export-env-from-config.sh

# Inject config sourcing into all s6 run/script files so HA options
# are available as environment variables when services start
RUN find /etc/s6-overlay/s6-rc.d/ -name script -o -name run | \
    xargs --no-run-if-empty sed -i '1 a\source /export-env-from-config.sh'
