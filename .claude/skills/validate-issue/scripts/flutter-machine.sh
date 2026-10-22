#!/bin/bash
# Drive `flutter run --machine` from separate shell calls: no PTY, no signals,
# no quit on stdin EOF. State lives in a run directory you choose.
#
#   flutter-machine.sh start   <rundir> <project-dir> <device> [flutter run args...]
#   flutter-machine.sh wait    <rundir> [seconds]      # until app.started; prints appId, wsUri, dtdUri
#   flutter-machine.sh reload  <rundir>                # hot reload
#   flutter-machine.sh restart <rundir>                # hot restart (not a cold start)
#   flutter-machine.sh ext     <rundir> <ext.name> ['{"json":"params"}']
#   flutter-machine.sh logs    <rundir>                # app.log events as plain text
#   flutter-machine.sh stop    <rundir>
#
# FLUTTER overrides the launcher (default: "mise exec -- flutter", which needs
# <project-dir> to be the directory holding mise.toml, i.e. mobile/).
# Needs jq. Every message is built with jq: one malformed line on stdin crashes
# the tool with a FormatException.
set -u
cmd="${1:-}"; run="${2:-}"
[ -n "$cmd" ] && [ -n "$run" ] || { sed -n '2,16p' "$0"; exit 64; }
out="$run/run.jsonl"; ctl="$run/ctl"

field() { # event-name json-key -> first value
  grep '^\[{' "$out" 2>/dev/null | jq -r --arg e "$1" --arg k "$2" '.[] | select(.event == $e) | .params[$k] // empty' | head -1
}
alive() { [ -f "$run/pid" ] && kill -0 "$(cat "$run/pid")" 2>/dev/null; }
app_id() { field app.start appId; }
send() { # method params-json [timeout]; prints the reply line
  alive || { echo "flutter run is not running (see $run/run.err)" >&2; return 3; }
  local id msg i=0 t="${3:-90}"
  id=$(( $(cat "$run/seq" 2>/dev/null || echo 100) + 1 )); echo "$id" > "$run/seq"
  msg=$(jq -nc --argjson id "$id" --arg m "$1" --argjson p "$2" '[{id: $id, method: $m, params: $p}]') || { echo "bad params json" >&2; return 64; }
  printf '%s\n' "$msg" > "$ctl"
  while [ "$i" -lt "$t" ]; do
    grep "^\[{\"id\":$id," "$out" && return 0
    alive || { echo "flutter run exited before replying (see $run/run.err)" >&2; return 3; }
    sleep 1; i=$((i + 1))
  done
  echo "no reply to $1 within ${t}s" >&2; return 1
}

case "$cmd" in
  start)
    proj="${3:?project dir}"; dev="${4:?device id}"; shift 4
    mkdir -p "$run"; rm -f "$ctl" "$out" "$run/run.err" "$run/seq"; mkfifo "$ctl"
    ( cd "$proj" && exec nohup ${FLUTTER:-mise exec -- flutter} run --machine -d "$dev" "$@" < "$ctl" > "$out" 2> "$run/run.err" ) &
    echo $! > "$run/pid"
    # A separate holder keeps a writer on the FIFO so the tool never sees EOF,
    # and exits with the tool, so a run nobody stops leaves no process behind.
    # It opens the FIFO read-write so it starts even if the tool never opens it.
    # (Handing the tool the FIFO read-write, `0<>ctl`, does not work on macOS:
    # the Dart VM then never delivers stdin.)
    nohup sh -c 'while kill -0 "$1" 2>/dev/null; do sleep 2; done' holder "$(cat "$run/pid")" 1<> "$ctl" 2>/dev/null &
    echo $! > "$run/holder.pid"
    echo "started pid $(cat "$run/pid"); next: wait $run"
    ;;
  wait)
    i=0; t="${3:-900}"
    until grep -q '"event":"app.started"' "$out" 2>/dev/null; do
      alive || { echo "flutter run exited:" >&2; tail -5 "$run/run.err" >&2; grep -v '^\[{' "$out" | tail -5 >&2; exit 3; }
      [ "$i" -ge "$t" ] && { echo "no app.started within ${t}s; last progress: $(grep '"event":"app.progress"' "$out" | tail -1 | cut -c1-160)" >&2; exit 1; }
      sleep 1; i=$((i + 1))
    done
    echo "appId=$(app_id)"; echo "wsUri=$(field app.debugPort wsUri)"; echo "dtdUri=$(field app.dtd uri)"
    ;;
  reload)  send app.restart "$(jq -nc --arg a "$(app_id)" '{appId: $a, fullRestart: false, reason: "manual"}')" ;;
  restart) send app.restart "$(jq -nc --arg a "$(app_id)" '{appId: $a, fullRestart: true, reason: "manual"}')" ;;
  ext)
    name="${3:?extension name}"; params="${4:-}"; [ -n "$params" ] || params='{}'
    send app.callServiceExtension "$(jq -nc --arg a "$(app_id)" --arg n "$name" --argjson p "$params" '{appId: $a, methodName: $n, params: $p}')"
    ;;
  logs)    # app.log events, plus the raw lines some devices print outside the JSON stream
           jq -Rr '(fromjson? // null) as $j | if $j == null then . elif ($j | type) == "array" then ($j[] | select(.event == "app.log") | .params.log) else empty end' "$out" ;;
  stop)
    send app.stop "$(jq -nc --arg a "$(app_id)" '{appId: $a}')" 30
    i=0; while alive && [ "$i" -lt 20 ]; do sleep 1; i=$((i + 1)); done
    [ -f "$run/holder.pid" ] && kill "$(cat "$run/holder.pid")" 2>/dev/null
    if alive; then echo "still running; kill it by pid: $(cat "$run/pid")" >&2; exit 1; fi
    echo "stopped"
    ;;
  *) sed -n '2,16p' "$0"; exit 64 ;;
esac
