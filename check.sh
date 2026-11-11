#!/usr/bin/env bash
# Off-box liveness check for the Genesis VPS.
#
# Fetches the platform's public, unauthenticated /health from OUTSIDE the VPS.
# A failure means the box, its network, Caddy or the platform is down: things
# the on-box watcher (genesis alerts check) cannot report, because it dies with
# the box.
#
# "degraded" (a background job is stale) passes: the on-box watcher owns that,
# and alerting on it here would double-post every 30 minutes.
#
# Usage:   ./check.sh [url]
# Exit:    0 = reachable and not unhealthy; 1 = failing (reason on stdout,
#          and in $GITHUB_OUTPUT as `reason` when run in Actions).
set -euo pipefail

readonly URL="${1:-${PINGER_URL:-https://platform.megacorp.us/health}}"
readonly ATTEMPTS=3
readonly RETRY_DELAY_SECONDS="${PINGER_RETRY_DELAY:-20}"
readonly TIMEOUT_SECONDS=15

body_file="$(mktemp)"
error_file="$(mktemp)"
trap 'rm -f "$body_file" "$error_file"' EXIT

# Prints a failure reason, or nothing when the endpoint is acceptable.
check_once() {
    local http_code status curl_error
    # curl's error goes to a file, not into http_code: on failure -w still
    # prints "000", and a multi-line reason would corrupt $GITHUB_OUTPUT.
    if ! http_code="$(curl -sS -o "$body_file" -w '%{http_code}' --max-time "$TIMEOUT_SECONDS" "$URL" 2>"$error_file")"; then
        curl_error="$(head -n 1 "$error_file")"
        echo "unreachable: ${curl_error:-curl failed}"
        return
    fi
    if [[ "$http_code" != "200" ]]; then
        echo "HTTP ${http_code}"
        return
    fi
    status="$(jq -r '.status // "missing"' "$body_file" 2>/dev/null || echo "unparseable body")"
    case "$status" in
        ok | degraded) ;;
        *) echo "status=${status}" ;;
    esac
}

reason=""
for attempt in $(seq 1 "$ATTEMPTS"); do
    reason="$(check_once)"
    if [[ -z "$reason" ]]; then
        echo "OK: ${URL} (attempt ${attempt})"
        exit 0
    fi
    echo "attempt ${attempt}/${ATTEMPTS} failed: ${reason}"
    if (( attempt < ATTEMPTS )); then
        sleep "$RETRY_DELAY_SECONDS"
    fi
done

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "reason=${reason}" >> "$GITHUB_OUTPUT"
fi
echo "FAILING: ${URL}: ${reason}"
exit 1
