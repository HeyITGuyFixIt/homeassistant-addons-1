#!/usr/bin/with-contenv bashio
# Generate/update planefence.config from Home Assistant add-on options.
# Runs via legacy-cont-init before planefence services start.
#
# The symlink /usr/share/planefence/persist -> /config/planefence is created
# at build time in the Dockerfile, so all s6 services see it immediately.
# This script just ensures the target directory exists and writes the config.
#
# First start: copies /planefence.config.template (saved at build time)
#              so the user has a fully documented config to customise.
# Every start:  updates only the keys managed by HA add-on options; all other
#              lines (custom settings added by the user) are left untouched.

# Source HA options as environment variables
. /export-env-from-config.sh

# The Dockerfile created /usr/share/planefence/persist -> /var/lib/planefence-persist
# so s6 services can start cleanly. Now re-point to the real persistent location.
#
# Priority:
#   1. /addon_configs/planefence  – real HA with addon_config:rw mapping
#   2. /config/planefence         – local testing (taskfile mounts /config)
#   3. /var/lib/planefence-persist – ephemeral stub (nothing else available)
if [ -d /addon_configs ]; then
    DATA_PERSIST="/addon_configs/planefence"
    echo "[ha-planefence-config] Using /addon_configs/planefence for persistent storage"
elif [ -d /config ]; then
    DATA_PERSIST="/config/planefence"
    echo "[ha-planefence-config] Using /config/planefence for persistent storage"
else
    DATA_PERSIST="/var/lib/planefence-persist"
    echo "[ha-planefence-config] WARNING: no persistent mount found, using ephemeral stub"
fi

mkdir -p "${DATA_PERSIST}"
mkdir -p "${DATA_PERSIST}/.internal"

# Re-point the symlink if it's not already pointing to the right place.
if [ "$(readlink /usr/share/planefence/persist)" != "${DATA_PERSIST}" ]; then
    # Copy anything the early s6 services may have written to the stub.
    cp -rn /var/lib/planefence-persist/. "${DATA_PERSIST}/" 2>/dev/null || true
    ln -sfn "${DATA_PERSIST}" /usr/share/planefence/persist
    echo "[ha-planefence-config] Re-pointed /usr/share/planefence/persist -> ${DATA_PERSIST}"
fi

CONFIG_FILE="${DATA_PERSIST}/planefence.config"
SAVED_TEMPLATE="${DATA_PERSIST}/planefence.config.RENAME-and-EDIT-me"

# Copy the upstream template to the persistent dir on first start so the
# user can edit it. The template was saved to /planefence.config.template
# in the Dockerfile before the persist dir was replaced with a symlink.
if [ ! -f "${SAVED_TEMPLATE}" ] && [ -f /planefence.config.template ]; then
    cp /planefence.config.template "${SAVED_TEMPLATE}"
    echo "[ha-planefence-config] Copied upstream template to ${SAVED_TEMPLATE}"
fi

# get-pa-alertlist.sh requires these files to exist or it crashes.
touch "${DATA_PERSIST}/plane-alert-db.txt"
touch "${DATA_PERSIST}/.internal/plane-alert-db.txt"

# Helper: set KEY=VALUE in config file.
# Updates existing line or appends if the key is not present yet.
set_config() {
    local key="$1"
    local value="$2"
    if grep -q "^${key}=" "${CONFIG_FILE}" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${CONFIG_FILE}"
    else
        echo "${key}=${value}" >> "${CONFIG_FILE}"
    fi
}

if [ ! -f "${CONFIG_FILE}" ]; then
    if [ -f "${SAVED_TEMPLATE}" ]; then
        cp "${SAVED_TEMPLATE}" "${CONFIG_FILE}"
        echo "[ha-planefence-config] First start — copied template to ${CONFIG_FILE}"
    else
        touch "${CONFIG_FILE}"
        echo "[ha-planefence-config] First start — template not found, created empty ${CONFIG_FILE}"
    fi
fi

# Warn if location placeholders were not resolved (HA location not configured).
if [ "${PF_LAT}" = "HOMEASSISTANT_LATITUDE" ] || [ "${PF_LON}" = "HOMEASSISTANT_LONGITUDE" ]; then
    echo "[ha-planefence-config] WARNING: PF_LAT/PF_LON are still placeholders."
    echo "[ha-planefence-config] Please set your Home Assistant location under"
    echo "[ha-planefence-config] Settings → System → General, or set PF_LAT/PF_LON"
    echo "[ha-planefence-config] manually in the add-on options."
fi

# Update all HA-managed keys (runs on every start, including first).
echo "[ha-planefence-config] Updating managed keys in ${CONFIG_FILE}"
set_config "FEEDER_LAT"            "${PF_LAT}"
set_config "FEEDER_LONG"           "${PF_LON}"
set_config "PF_MAXDIST"            "${PF_MAXDIST:-50}"
set_config "PF_MAXALT"             "${PF_MAXALT:-10000}"
set_config "PF_SOCK30003HOST"      "${PF_SOCK30003HOST:-adsb-multi-portal-feeder}"
set_config "PF_SOCK30003PORT"      "${PF_SOCK30003PORT:-30003}"
set_config "PF_DISCORD"            "${PA_DISCORD:+true}"
set_config "PF_DISCORD_WEBHOOKURL" "${PA_DISCORD:-}"
set_config "MASTODON_SERVER"       "${PA_MASTODON_SERVER:-}"
set_config "MASTODON_ACCESS_TOKEN" "${PA_MASTODON_ACCESS_TOKEN:-}"
set_config "TELEGRAM_BOT_TOKEN"    "${PA_TELEGRAM_BOTTOKEN:-}"
set_config "TELEGRAM_CHAT_ID"      "${PA_TELEGRAM_CHATID:-}"
set_config "PF_ALERTLIST"          "plane-alert-db.txt"
set_config "PA_EXCLUSIONS"         "${PA_EXCLUSIONS:-}"
set_config "PF_OPENAIP_LAYER"      "${PF_OPENAIP_LAYER:-OFF}"

echo "[ha-planefence-config] Done."

# Set system timezone so all planefence services use the correct time
if [ -n "${TZ}" ] && [ -f "/usr/share/zoneinfo/${TZ}" ]; then
    ln -sf "/usr/share/zoneinfo/${TZ}" /etc/localtime
    echo "${TZ}" > /etc/timezone
    echo "[ha-planefence-config] Timezone set to ${TZ}"
fi

# Signal to 00-container-startup (patched in Dockerfile) that the real
# planefence.config has been written and it is safe to proceed.
touch /run/ha-planefence-ready
echo "[ha-planefence-config] Signalled ready (/run/ha-planefence-ready)"
