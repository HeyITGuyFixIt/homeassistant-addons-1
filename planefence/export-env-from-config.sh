#!/bin/bash
#
# Reads the Home Assistant Add-On configuration from /data/options.json
# and exports all values as environment variables.
# Replaces HOMEASSISTANT_LATITUDE / HOMEASSISTANT_LONGITUDE placeholders
# with actual values from the HA Supervisor API.
#
# This script must be sourced ($ source /export-env-from-config.sh)

# Only run once per process to avoid re-sourcing overhead
if [ -n "$_HA_CONFIG_EXPORTED" ]; then
    return 0
fi
export _HA_CONFIG_EXPORTED=1

if [ ! -f '/data/options.json' ]; then
    echo 'ERROR: /data/options.json not found' >>/dev/stderr
    return 1
fi

# Fetch coordinates from HA Supervisor API
_HA_HTTP_STATUS=$(curl -s -o /tmp/ha_api_response --write-out "%{http_code}" \
    --connect-timeout 5 --max-time 10 \
    -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
    -H "Content-Type: application/json" \
    http://supervisor/core/api/config)
_CURL_EXIT=$?
_HA_CONFIG=$(cat /tmp/ha_api_response 2>/dev/null)

if [ $_CURL_EXIT -ne 0 ]; then
    echo "[export-env] WARNING: HA API call failed (curl exit ${_CURL_EXIT}, http ${_HA_HTTP_STATUS}). Lat/lon placeholders will not be resolved." >&2
    echo "[export-env] Response: ${_HA_CONFIG}" >&2
elif [ -z "$_HA_CONFIG" ]; then
    echo "[export-env] WARNING: HA API returned empty response. Lat/lon placeholders will not be resolved." >&2
else
    # HA Core API returns {"latitude":...} directly; Supervisor may wrap it as
    # {"result":"ok","data":{"latitude":...}}. Handle both formats.
    _HA_LAT=$(echo "$_HA_CONFIG" | jq -r '.latitude // .data.latitude // empty' 2>/dev/null)
    _HA_LON=$(echo "$_HA_CONFIG" | jq -r '.longitude // .data.longitude // empty' 2>/dev/null)
    if [ -z "$_HA_LAT" ] || [ -z "$_HA_LON" ]; then
        echo "[export-env] WARNING: HA location not set (lat=${_HA_LAT} lon=${_HA_LON}). Set it under Settings → System → General." >&2
    else
        echo "[export-env] Resolved location from HA: lat=${_HA_LAT} lon=${_HA_LON}"
    fi
fi

# Export all options as environment variables, replacing HA placeholders
while read -rd $'' line; do
    if [[ $line == *"HOMEASSISTANT_LATITUDE"* ]] && [ -n "$_HA_LAT" ]; then
        line=$(echo "$line" | sed "s/HOMEASSISTANT_LATITUDE/$_HA_LAT/")
    fi
    if [[ $line == *"HOMEASSISTANT_LONGITUDE"* ]] && [ -n "$_HA_LON" ]; then
        line=$(echo "$line" | sed "s/HOMEASSISTANT_LONGITUDE/$_HA_LON/")
    fi
    export "$line"
done < <(jq -r 'to_entries | map("\(.key)=\(.value)\u0000")[]' /data/options.json)
