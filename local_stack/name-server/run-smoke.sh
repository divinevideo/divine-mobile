#!/usr/bin/env bash
# Sourced by the local test runners after setting SCRIPT_DIR and COMPOSE.
# Never widen the registry's loopback binding to accommodate a test container.
run_name_server_smoke() {
  local container details image health config service binding engine os_type endpoint
  container="$("${COMPOSE[@]}" ps -q name-server)" || return
  if [[ -z "$container" || "$container" == *$'\n'* ]]; then
    echo "ERROR: expected one running name-server in this Compose project." >&2
    return 1
  fi
  details="$(docker inspect --format '{{.Image}}|{{.State.Health.Status}}|{{index .Config.Labels "com.docker.compose.project.config_files"}}|{{index .Config.Labels "com.docker.compose.service"}}|{{range (index .NetworkSettings.Ports "8787/tcp")}}{{.HostIp}}:{{.HostPort}}{{end}}' "$container")" || return
  IFS='|' read -r image health config service binding <<< "$details"
  if [[ -z "$image" || "$health" != healthy ||
        "$config" != "$SCRIPT_DIR/docker-compose.yml" ||
        "$service" != name-server || "$binding" != 127.0.0.1:43005 ]]; then
    echo "ERROR: smoke requires this checkout's healthy loopback-only registry on port 43005." >&2
    return 1
  fi
  engine="$(docker info --format '{{.OperatingSystem}}')" || return
  os_type="$(docker info --format '{{.OSType}}')" || return
  if [[ -z "$engine" || -z "$os_type" ]]; then
    echo "ERROR: could not classify the Docker engine." >&2
    return 1
  fi
  if [[ "$os_type" == linux && "$engine" != *"Docker Desktop"* &&
        "$(uname -s)" == Linux ]]; then
    # Host networking must mean this machine, not a remote daemon's host.
    # Reject an environment override without inspecting its value.
    if [[ ${DOCKER_HOST+x} ]]; then
      echo "ERROR: native smoke requires a local Docker context without DOCKER_HOST." >&2
      return 1
    fi
    endpoint="$(docker context inspect --format '{{.Endpoints.docker.Host}}')" || return
    if [[ "$endpoint" != unix://* ]]; then
      echo "ERROR: native smoke requires a local Unix-socket Docker context." >&2
      return 1
    fi
    # Native Engine's host-gateway is a bridge address, not host loopback.
    # Use the verified server's immutable image, not a shared movable tag.
    docker run --rm --network host \
      -e NAME_SERVER_TRANSPORT=http://127.0.0.1:43005 \
      --entrypoint node "$image" /app/smoke.mjs "$@"
  else
    # Desktop (including Desktop for Linux) forwards host.docker.internal.
    "${COMPOSE[@]}" run --rm --no-deps name-server-smoke "$@"
  fi
}
