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

# Check if options.json actually contains HOMEASSISTANT_* placeholders that need resolving.
# If PF_LAT/PF_LON are already real coordinates, skip the Supervisor API entirely.
_HA_LAT=""
_HA_LON=""
_HA_NEEDS_RESOLVE=false

if grep -q 'HOMEASSISTANT_LATITUDE\|HOMEASSISTANT_LONGITUDE' /data/options.json 2>/dev/null; then
    _HA_NEEDS_RESOLVE=true
fi

if [ "$_HA_NEEDS_RESOLVE" = true ]; then
    # Fetch coordinates from HA Supervisor API.
    # HA Core may not be ready when the addon starts, so retry a few times.
    _HA_MAX_RETRIES=10
    _HA_RETRY_DELAY=3

    echo "[export-env] options.json contains HOMEASSISTANT_* placeholders — need to resolve via Supervisor API"
    echo "[export-env] SUPERVISOR_TOKEN is ${SUPERVISOR_TOKEN:+set (${#SUPERVISOR_TOKEN} chars)}${SUPERVISOR_TOKEN:-EMPTY/UNSET}"

    # Diagnostic: verify basic Supervisor API access first
    echo "[export-env] Testing basic Supervisor connectivity..."
    _diag_status=$(curl -s -o /tmp/ha_diag --write-out "%{http_code}" \
        --connect-timeout 5 --max-time 10 \
        -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
        http://supervisor/supervisor/info)
    _diag_exit=$?
    _diag_body=$(cat /tmp/ha_diag 2>/dev/null)
    echo "[export-env]   GET /supervisor/info => curl_exit=${_diag_exit} http=${_diag_status} body=${_diag_body:0:200}"

    # Try multiple API endpoints — different Supervisor versions use different paths.
    # The Core API proxy is the standard way, but older setups may use /homeassistant/.
    _HA_API_ENDPOINTS="http://supervisor/core/api/config http://supervisor/homeassistant/api/config"

    echo "[export-env] Fetching HA location (up to ${_HA_MAX_RETRIES} attempts, ${_HA_RETRY_DELAY}s apart)..."

    for _attempt in $(seq 1 $_HA_MAX_RETRIES); do
        for _endpoint in $_HA_API_ENDPOINTS; do
            echo "[export-env] Attempt ${_attempt}/${_HA_MAX_RETRIES}: GET ${_endpoint}"
            _HA_HTTP_STATUS=$(curl -s -o /tmp/ha_api_response --write-out "%{http_code}" \
                --connect-timeout 5 --max-time 10 \
                -H "Authorization: Bearer ${SUPERVISOR_TOKEN}" \
                "$_endpoint")
            _CURL_EXIT=$?
            _HA_CONFIG=$(cat /tmp/ha_api_response 2>/dev/null)

            echo "[export-env]   curl exit=${_CURL_EXIT}, http_status=${_HA_HTTP_STATUS}, response_length=${#_HA_CONFIG}"
            echo "[export-env]   response body: ${_HA_CONFIG:0:300}"

            # Skip to next endpoint on network error
            if [ "$_CURL_EXIT" -ne 0 ]; then
                echo "[export-env]   FAILED: curl error ${_CURL_EXIT}" >&2
                continue
            fi

            # Skip to next endpoint on auth/server error
            if [ "$_HA_HTTP_STATUS" != "200" ]; then
                echo "[export-env]   FAILED: HTTP ${_HA_HTTP_STATUS}" >&2
                continue
            fi

            if [ -z "$_HA_CONFIG" ]; then
                echo "[export-env]   FAILED: response body is empty" >&2
                continue
            fi

            # HA Core API returns {"latitude":...} directly; Supervisor may wrap it as
            # {"result":"ok","data":{"latitude":...}}. Handle both formats.
            _HA_LAT=$(echo "$_HA_CONFIG" | jq -r '.latitude // .data.latitude // empty' 2>/dev/null)
            _HA_LON=$(echo "$_HA_CONFIG" | jq -r '.longitude // .data.longitude // empty' 2>/dev/null)
            echo "[export-env]   Parsed: lat=[${_HA_LAT}] lon=[${_HA_LON}]"

            if [ -n "$_HA_LAT" ] && [ -n "$_HA_LON" ]; then
                echo "[export-env] Resolved location from HA: lat=${_HA_LAT} lon=${_HA_LON}"
                break 2  # break out of both loops
            fi

            echo "[export-env]   FAILED: lat/lon empty after parsing" >&2
        done

        # Only reached if no endpoint succeeded this round
        if [ -n "$_HA_LAT" ] && [ -n "$_HA_LON" ]; then
            break
        fi
        echo "[export-env]   All endpoints failed. Retrying in ${_HA_RETRY_DELAY}s..." >&2
        sleep "$_HA_RETRY_DELAY"
    done

    if [ -z "$_HA_LAT" ] || [ -z "$_HA_LON" ]; then
        echo "[export-env] WARNING: Could not resolve HA location after ${_HA_MAX_RETRIES} attempts." >&2
        echo "[export-env] HOMEASSISTANT_LATITUDE/LONGITUDE placeholders will NOT be replaced." >&2
        echo "[export-env] Diagnostics: /supervisor/info returned HTTP ${_diag_status}" >&2
        echo "[export-env] Fix: Set your location under Settings → System → General," >&2
        echo "[export-env]   or set PF_LAT/PF_LON to numeric values in the addon options." >&2
    fi
else
    echo "[export-env] PF_LAT/PF_LON are already set to coordinates in options.json — skipping Supervisor API call"
fi

# Export all options as environment variables, replacing HA placeholders
echo "[export-env] Exporting options from /data/options.json:"
while read -rd $'' line; do
    if [[ $line == *"HOMEASSISTANT_LATITUDE"* ]]; then
        if [ -n "$_HA_LAT" ]; then
            echo "[export-env]   ${line}  -->  replacing HOMEASSISTANT_LATITUDE with ${_HA_LAT}"
            line=$(echo "$line" | sed "s/HOMEASSISTANT_LATITUDE/$_HA_LAT/")
        else
            echo "[export-env]   ${line}  -->  WARNING: keeping unresolved placeholder (no HA lat available)"
        fi
    fi
    if [[ $line == *"HOMEASSISTANT_LONGITUDE"* ]]; then
        if [ -n "$_HA_LON" ]; then
            echo "[export-env]   ${line}  -->  replacing HOMEASSISTANT_LONGITUDE with ${_HA_LON}"
            line=$(echo "$line" | sed "s/HOMEASSISTANT_LONGITUDE/$_HA_LON/")
        else
            echo "[export-env]   ${line}  -->  WARNING: keeping unresolved placeholder (no HA lon available)"
        fi
    fi
    echo "[export-env]   export ${line}"
    export "$line"
done < <(jq -r 'to_entries | map("\(.key)=\(.value)\u0000")[]' /data/options.json)
echo "[export-env] Done exporting options."
