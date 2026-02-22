#!/bin/bash
# Generate/update planefence.config from Home Assistant add-on options.
# Runs via legacy-cont-init before planefence services start.
#
# First start: copies the upstream template (planefence.config.RENAME-and-EDIT-me)
#              so the user has a fully documented config to customise.
# Every start:  updates the keys managed by the HA add-on options; all other
#              lines (custom settings added by the user) are left untouched.

# Source HA options as environment variables
. /export-env-from-config.sh

# /addon_config is mounted by HA Supervisor (map: addon_config:rw in config.yaml).
# It lives at /addon_configs/planefence/ on the host, so the VS Code addon and
# other tools can reach it. Symlink planefence's expected persist dir here so
# all noise logs, history, plane-alert-db and planefence.config survive restarts
# and are user-accessible.
DATA_PERSIST="/addon_config"
PERSIST_DIR="/usr/share/planefence/persist"

mkdir -p "${DATA_PERSIST}"
mkdir -p "${DATA_PERSIST}/.internal"

if [ ! -L "${PERSIST_DIR}" ]; then
    rm -rf "${PERSIST_DIR}"
    ln -sf "${DATA_PERSIST}" "${PERSIST_DIR}"
    echo "[ha-planefence-config] Linked ${PERSIST_DIR} -> ${DATA_PERSIST}"
fi

CONFIG_FILE="${PERSIST_DIR}/planefence.config"
TEMPLATE_FILE="${PERSIST_DIR}/planefence.config.RENAME-and-EDIT-me"

# get-pa-alertlist.sh requires these files to exist or it crashes.
touch "${PERSIST_DIR}/plane-alert-db.txt"
touch "${PERSIST_DIR}/.internal/plane-alert-db.txt"

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
    # First start: wait for planefence to drop the template, then copy it.
    # The template is written by planefence's own startup into PERSIST_DIR,
    # so it should already be there. Fall back to an empty file just in case.
    if [ -f "${TEMPLATE_FILE}" ]; then
        cp "${TEMPLATE_FILE}" "${CONFIG_FILE}"
        echo "[ha-planefence-config] First start — copied template to ${CONFIG_FILE}"
    else
        touch "${CONFIG_FILE}"
        echo "[ha-planefence-config] First start — template not found, created empty ${CONFIG_FILE}"
    fi
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
