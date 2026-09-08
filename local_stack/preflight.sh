#!/usr/bin/env bash
# Pre-flight and post-mortem diagnostics for the local E2E stack.
#
# Sourced by up.sh. Two jobs:
#   1. preflight_ports  — before starting anything, prove every host port the
#      stack publishes is free (or already ours). The raw daemon error
#      ("Bind for 0.0.0.0:16380 failed: port is already allocated") names
#      neither the service that wanted the port nor what is holding it.
#   2. stack_failure_is_transient / stack_failure_report — after a failed
#      `up`, tell the operator which services are down and what to do next.
#
# The port list is read from docker-compose.yml via `docker compose config`,
# so it cannot drift from the stack definition.
#
# `mise run local_up` calls plain `bash`, which on macOS is 3.2. No
# associative arrays: every port map below is an indexed array subscripted by
# the port number, which behaves identically on 3.2 and 4+.

# --- Port list, straight from the compose file ------------------------------

# stdout: "<service> <host_port>" per published TCP port.
_stack_published_ports() {
    python3 -c '
import json, sys

doc = json.load(sys.stdin)
for service, config in sorted((doc.get("services") or {}).items()):
    for port in config.get("ports") or []:
        if port.get("protocol", "tcp") != "tcp":
            continue
        published = str(port.get("published") or "")
        if not published:
            continue
        low, _, high = published.partition("-")
        try:
            span = range(int(low), int(high or low) + 1)
        except ValueError:
            continue
        for host_port in span:
            print(service, host_port)
'
}

_stack_project_name() {
    python3 -c 'import json, sys; print(json.load(sys.stdin).get("name", ""))'
}

# --- Host listeners ---------------------------------------------------------

# stdout: one "<address>:<port>" per listening TCP socket.
# `ss` is iproute2, so it does not exist on macOS; `lsof` is there instead.
# Returns 1 when neither is installed. Returns 2 when an available tool errors,
# so the caller can fail closed instead of treating the result as port-free.
_stack_listen_addrs() {
    local tool_err tool_rc
    if command -v ss >/dev/null 2>&1; then
        tool_err="$(mktemp)"
        ss -Hltn 2>"$tool_err" | awk '{ print $4 }'
        tool_rc="${PIPESTATUS[0]}"
        if [[ "$tool_rc" -ne 0 ]]; then
            [[ ! -s "$tool_err" ]] || sed 's/^/WARNING: ss failed while enumerating listeners: /' "$tool_err" >&2
            rm -f "$tool_err"
            return 2
        fi
        rm -f "$tool_err"
    elif command -v lsof >/dev/null 2>&1; then
        # -Fn emits one "n<address>:<port>" record per socket, which spares us
        # the header line and the space-separated NAME column. Without sudo it
        # only sees our own processes — enough for Docker Desktop's proxy.
        tool_err="$(mktemp)"
        lsof -nP -iTCP -sTCP:LISTEN -Fn 2>"$tool_err" | sed -n 's/^n//p'
        tool_rc="${PIPESTATUS[0]}"
        # lsof exits 1 when no sockets match. That is a clean empty listener
        # list as long as stderr is empty; stderr means the check is blind.
        if [[ "$tool_rc" -ne 0 && -s "$tool_err" ]]; then
            sed 's/^/WARNING: lsof failed while enumerating listeners: /' "$tool_err" >&2
            rm -f "$tool_err"
            return 2
        fi
        rm -f "$tool_err"
    else
        return 1
    fi
    return 0
}

# stdout: the command that names what holds <port>, for whichever of ss/lsof
# this machine actually has.
_stack_port_finder_cmd() {
    local port="$1"
    if command -v ss >/dev/null 2>&1; then
        printf 'ss -ltnp "sport = :%s"' "$port"
    else
        printf 'sudo lsof -nP -iTCP:%s -sTCP:LISTEN' "$port"
    fi
}

# --- Pre-flight -------------------------------------------------------------

# preflight_ports <compose_file>
# Returns 0 if every published host port is free or held by this project's own
# containers; 1 (with an actionable report on stderr) otherwise.
preflight_ports() {
    local compose_file="$1"
    local config_json config_err project ports

    if ! docker ps --format '{{.Names}}' >/dev/null 2>&1; then
        local daemon_hint="systemctl status docker"
        if [[ "$(uname -s)" == "Darwin" ]]; then
            daemon_hint="open -a Docker"
        fi
        echo "ERROR: cannot talk to the Docker daemon. Is it running? (${daemon_hint})" >&2
        return 1
    fi

    config_err="$(mktemp)"
    if ! config_json="$(docker compose -f "$compose_file" config --format json 2>"$config_err")"; then
        echo "ERROR: could not parse ${compose_file}:" >&2
        cat "$config_err" >&2
        rm -f "$config_err"
        return 1
    fi
    rm -f "$config_err"

    # Fail closed. An unreadable port list is indistinguishable from "the stack
    # publishes no ports", and passing on it hands the operator back the
    # anonymous daemon error this whole check exists to replace.
    if ! command -v python3 >/dev/null 2>&1; then
        echo "ERROR: the port pre-flight needs python3 on PATH, and it is missing." >&2
        return 1
    fi

    if ! project="$(printf '%s' "$config_json" | _stack_project_name)" ||
        ! ports="$(printf '%s' "$config_json" | _stack_published_ports)"; then
        echo "ERROR: could not read the published ports out of ${compose_file}." >&2
        return 1
    fi

    if [[ -z "$project" ]]; then
        echo "ERROR: ${compose_file} resolved to an empty compose project name," >&2
        echo "       so this stack's own containers cannot be told apart from others." >&2
        return 1
    fi

    if [[ -z "$ports" ]]; then
        return 0
    fi

    # port -> space-separated local addresses currently listening on it
    local listen_addrs=()
    local listeners_known=1
    local listener_lines listener_rc local_addr port
    if listener_lines="$(_stack_listen_addrs)"; then
        while read -r local_addr; do
            port="${local_addr##*:}"
            [[ "$port" =~ ^[0-9]+$ ]] || continue
            listen_addrs["$port"]+="${local_addr} "
        done <<<"$listener_lines"
    else
        listener_rc=$?
        if [[ "$listener_rc" -eq 2 ]]; then
            echo "ERROR: could not enumerate host TCP listeners; port safety is unknown." >&2
            return 1
        fi
        listeners_known=0
    fi

    # port -> container name / owning compose project (empty if standalone)
    local port_container=() port_project=()
    local name proj portspec host_port
    # `|` rather than tab: tab is IFS whitespace, so bash collapses a run of
    # them and an empty middle field disappears. A standalone container has no
    # compose-project label, which is exactly the stale-container case this
    # check exists to catch — with tabs its ports column shifts into `proj`
    # and the container is misreported as an anonymous host process.
    while IFS='|' read -r name proj portspec; do
        [[ -n "$name" ]] || continue
        while read -r host_port; do
            [[ -n "$host_port" ]] || continue
            port_container["$host_port"]="$name"
            port_project["$host_port"]="$proj"
        done < <(grep -oE ':[0-9]+->' <<<"$portspec" | tr -d ':>-')
    done < <(docker ps --format '{{.Names}}|{{.Label "com.docker.compose.project"}}|{{.Ports}}' 2>/dev/null)

    if ((listeners_known == 0)); then
        {
            echo ""
            echo "WARNING: host listener enumeration is unavailable, so a port held by"
            echo "         a plain host process cannot be detected. Ports held by"
            echo "         containers are still checked below."
        } >&2
    fi

    local service conflicts=0 holder holder_project addrs
    while read -r service port; do
        holder="${port_container[$port]:-}"
        holder_project="${port_project[$port]:-}"
        addrs="${listen_addrs[$port]:-}"

        # A container that published the port clashes even when the listener
        # enumeration cannot see the socket — no ss/lsof, or a listener owned
        # by another user.
        [[ -n "$addrs" || -n "$holder" ]] || continue

        # Already published by our own stack — `up` is idempotent, not a clash.
        if [[ -n "$holder" && "$holder_project" == "$project" ]]; then
            continue
        fi

        if ((conflicts == 0)); then
            {
                echo ""
                echo "ERROR: host ports the local stack needs are already in use."
                echo ""
            } >&2
        fi
        conflicts=$((conflicts + 1))

        if [[ -n "$holder" ]]; then
            local owner_desc
            if [[ -n "$holder_project" ]]; then
                owner_desc="compose project \"${holder_project}\""
            else
                owner_desc="standalone container (no compose project)"
            fi
            {
                printf '  port %-6s wanted by service "%s"\n' "$port" "$service"
                printf '            held by container "%s" — %s\n' "$holder" "$owner_desc"
                printf '            remedy: docker rm -f %s\n' "$holder"
            } >&2
        else
            {
                printf '  port %-6s wanted by service "%s"\n' "$port" "$service"
                printf '            held by a host process (not a container), listening on: %s\n' \
                    "${addrs% }"
                printf '            find it: %s\n' "$(_stack_port_finder_cmd "$port")"
            } >&2
        fi
        echo "" >&2
    done <<<"$ports"

    if ((conflicts > 0)); then
        {
            echo "${conflicts} port conflict(s). Nothing was started."
            echo "Stale containers from earlier test runs are the usual cause:"
            printf '    docker ps --format %s\n' "'{{.Names}}\t{{.Status}}\t{{.Ports}}'"
            echo ""
        } >&2
        return 1
    fi

    return 0
}

# --- Post-mortem ------------------------------------------------------------

# Startup races that a plain retry fixes: the container came up before Docker's
# embedded DNS had the dependency's alias, so the name did not resolve.
_STACK_TRANSIENT_RE='no such host|Temporary failure in name resolution|Name or service not known|i/o timeout'

# _stack_down_services <compose_file> <service>...
# stdout: "<service>|<state>" per service that is not up. One-shot jobs
# (migrations, seeding) that exited 0 did their work and are not failures.
_stack_down_services() {
    local compose_file="$1"
    shift

    local service state exit_code
    # `|` for the same reason as above: an empty middle field survives.
    while IFS='|' read -r service state exit_code; do
        [[ -n "$service" ]] || continue
        [[ "$state" == "running" ]] && continue
        [[ "$state" == "exited" && "$exit_code" == "0" ]] && continue
        echo "${service}|${state}"
    done < <(docker compose -f "$compose_file" ps -a --format '{{.Service}}|{{.State}}|{{.ExitCode}}' "$@" 2>/dev/null)
}

# stack_failure_is_transient <compose_file> <up_log> <service>...
# True when the failure looks like a DNS/startup race rather than a real break.
stack_failure_is_transient() {
    local compose_file="$1" up_log="$2"
    shift 2

    if grep -qE "$_STACK_TRANSIENT_RE" "$up_log" 2>/dev/null; then
        return 0
    fi

    # The daemon error is usually generic ("dependency failed to start"); the
    # real signature is in the failed containers' own logs. Only theirs — an
    # `i/o timeout` in the recent output of a service that came up fine would
    # otherwise buy two more pointless `up --wait` cycles before the real
    # report prints.
    local down_services=() service
    while IFS='|' read -r service _; do
        [[ -n "$service" ]] || continue
        down_services+=("$service")
    done < <(_stack_down_services "$compose_file" "$@")

    ((${#down_services[@]} > 0)) || return 1

    local logs
    logs="$(docker compose -f "$compose_file" logs --tail=50 "${down_services[@]}" 2>/dev/null || true)"
    grep -qE "$_STACK_TRANSIENT_RE" <<<"$logs"
}

# stack_service_status <compose_file> <service>...
# The per-service state table, on stderr.
stack_service_status() {
    local compose_file="$1"
    shift

    {
        echo "Service status:"
        docker compose -f "$compose_file" ps -a --format '{{.Service}}	{{.State}}	{{.Status}}' \
            "$@" 2>/dev/null | sed 's/^/  /' || true
        echo ""
    } >&2
}

# stack_bypass_hint <script_dir> <lead_in>
# How to run tests anyway, on stderr.
stack_bypass_hint() {
    local script_dir="$1" lead_in="$2"

    {
        echo "$lead_in"
        echo "profile.sh skips the local_up gate and runs patrol directly:"
        echo ""
        if [[ -n "${E2E_TEST_PATH:-}" ]]; then
            echo "    bash ${script_dir}/profile.sh ${E2E_TEST_PATH}"
        else
            echo "    bash ${script_dir}/profile.sh <test_path>"
            echo ""
            echo "e.g. bash ${script_dir}/profile.sh integration_test/auth/auth_journey_test.dart"
        fi
        echo ""
    } >&2
}

# stack_failure_report <compose_file> <script_dir> <service>...
# Says which services are healthy vs down, and how to run tests anyway.
stack_failure_report() {
    local compose_file="$1" script_dir="$2"
    shift 2

    {
        echo ""
        echo "=== Local stack failed to come up ==="
        echo ""
    } >&2

    stack_service_status "$compose_file" "$@"

    local service state service_logs dirty_migration=0
    while IFS='|' read -r service state; do
        [[ -n "$service" ]] || continue
        service_logs="$(docker compose -f "$compose_file" logs --tail=20 --no-log-prefix "$service" 2>&1 || true)"
        if [[ "$service" == "funnelcake-migrate" ]] &&
            grep -qiE 'dirty database version|migration .* is dirty|schema_migrations.*dirty' <<<"$service_logs"; then
            dirty_migration=1
        fi
        {
            echo "--- last 20 log lines: ${service} (${state}) ---"
            if [[ -n "$service_logs" ]]; then
                # shellcheck disable=SC2001  # indenting every line, not a substring swap
                sed 's/^/    /' <<<"$service_logs"
            else
                echo "    (no output — the container never started)"
            fi
            echo ""
        } >&2
    done < <(_stack_down_services "$compose_file" "$@")

    if [[ "$dirty_migration" -eq 1 ]]; then
        {
            echo "The Funnelcake migration ledger is dirty, so relay and API cannot start."
            echo "Reset and retry only if all local stack data is disposable."
            echo "This deletes all local stack data, not just Funnelcake's database:"
            echo ""
            echo "    mise run local_reset"
            echo ""
        } >&2
    fi

    stack_bypass_hint "$script_dir" \
        "A service being down does NOT block tests that never call it."
}

# --- Image staleness ---------------------------------------------------------
#
# `pull_policy: always` re-checks the registry every run, but when the remote
# digest has not moved that is a no-op: `docker compose pull` prints "Pulled"
# and nothing changes. A previous publishing failure left these images frozen
# for months, so retain an independent age check even though publishing works.
#
# This warns; it never blocks. GHCR is queried anonymously (no credentials of
# any kind), and every failure path returns 0 so a rate limit, an offline
# laptop, or a GHCR outage cannot stop `up.sh`.

_STACK_STALE_AFTER_DAYS="${STACK_STALE_AFTER_DAYS:-45}"

# _stack_ghcr_image_age <package>
# stdout: "<age_in_days> <tag_count>". Returns 1 if it could not be determined.
_stack_ghcr_image_age() {
    local package="$1" token manifest digest created tags

    token="$(curl -fsS --max-time 10 \
        "https://ghcr.io/token?scope=repository:divinevideo/${package}:pull&service=ghcr.io" \
        2>/dev/null | python3 -c 'import sys,json; print(json.load(sys.stdin).get("token",""))' 2>/dev/null)" || return 1
    [[ -n "$token" ]] || return 1

    manifest="$(curl -fsS --max-time 10 -H "Authorization: Bearer ${token}" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        "https://ghcr.io/v2/divinevideo/${package}/manifests/latest" 2>/dev/null)" || return 1
    digest="$(python3 -c 'import sys,json; print((json.load(sys.stdin).get("config") or {}).get("digest",""))' <<<"$manifest" 2>/dev/null)" || return 1
    [[ -n "$digest" ]] || return 1

    created="$(curl -fsSL --max-time 10 -H "Authorization: Bearer ${token}" \
        "https://ghcr.io/v2/divinevideo/${package}/blobs/${digest}" 2>/dev/null |
        python3 -c 'import sys,json; print(json.load(sys.stdin).get("created",""))' 2>/dev/null)" || return 1
    [[ -n "$created" ]] || return 1

    tags="$(curl -fsS --max-time 10 -H "Authorization: Bearer ${token}" \
        "https://ghcr.io/v2/divinevideo/${package}/tags/list?n=1000" 2>/dev/null |
        python3 -c 'import sys,json; print(len(json.load(sys.stdin).get("tags") or []))' 2>/dev/null)" || tags=0

    # Registry timestamps carry up to nanosecond precision and either "Z" or a
    # numeric offset, e.g. "2026-02-24T12:31:46.817075705-03:00".
    # datetime.fromisoformat rejects a 9-digit fraction, so drop it entirely —
    # sub-second precision is irrelevant to an age measured in days.
    python3 -c '
import datetime, re, sys
m = re.match(
    r"^(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2})(?:\.\d+)?(Z|[+-]\d{2}:?\d{2})?$",
    sys.argv[1].strip(),
)
if not m:
    sys.exit(1)
base, offset = m.group(1), m.group(2) or "Z"
if offset == "Z":
    offset = "+00:00"
elif ":" not in offset:
    offset = offset[:3] + ":" + offset[3:]
created = datetime.datetime.fromisoformat(base + offset)
now = datetime.datetime.now(datetime.timezone.utc)
print(int((now - created).total_seconds() // 86400), sys.argv[2])
' "$created" "$tags" 2>/dev/null || return 1
}

# preflight_image_staleness <script_dir>
# Warns when the pinned funnelcake images are stale. Always returns 0.
preflight_image_staleness() {
    local script_dir="$1"
    local package age_and_tags age tags stale=""

    # An explicit image override means the developer already knows.
    if [[ -n "${FUNNELCAKE_RELAY_IMAGE:-}${FUNNELCAKE_API_IMAGE:-}${FUNNELCAKE_MIGRATE_IMAGE:-}" ]]; then
        return 0
    fi

    for package in funnelcake-migrate funnelcake-relay funnelcake-api; do
        age_and_tags="$(_stack_ghcr_image_age "$package")" || continue
        age="${age_and_tags% *}"
        tags="${age_and_tags#* }"
        if [[ "$age" -ge "$_STACK_STALE_AFTER_DAYS" ]]; then
            stale="${stale}  ${package}: built ${age} days ago (${tags} tag(s) published)
"
        fi
    done

    [[ -n "$stale" ]] || return 0

    {
        echo ""
        echo "WARNING: the pinned funnelcake images are stale."
        echo ""
        printf '%s' "$stale"
        echo ""
        echo "\`docker compose pull\` reports success because the remote digest has not"
        echo "moved — there is nothing newer to pull. Check the latest divine-funnelcake"
        echo "CI run's GHCR login and push steps before trusting local relay behaviour."
        echo ""
        echo "To run against current funnelcake instead:"
        echo ""
        echo "    bash ${script_dir}/build_funnelcake.sh"
        echo "    # Add the printed override lines to ${script_dir}/.env."
        echo "    mise run local_reset"
        echo ""
    } >&2
    return 0
}
