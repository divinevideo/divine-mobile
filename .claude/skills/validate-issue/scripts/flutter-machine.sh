#!/bin/bash
# Drive `flutter run --machine` from separate shell calls: no PTY, no signals,
# no quit on stdin EOF. State lives in a run directory you choose.
#
#   flutter-machine.sh start   <rundir> <project-dir> <device> [flutter run args...]
#   flutter-machine.sh wait    <rundir> [seconds]      # until app.started; prints appId, wsUri, dtdUri
#   flutter-machine.sh status  <rundir>                # state, pid, appId, URIs; exit 0 started, 1 still starting, 3 not running
#   flutter-machine.sh reload  <rundir>                # hot reload
#   flutter-machine.sh restart <rundir>                # hot restart (not a cold start)
#   flutter-machine.sh ext     <rundir> <ext.name> ['{"json":"params"}']
#   flutter-machine.sh logs    <rundir>                # app.log events as plain text
#   flutter-machine.sh vmlog   <rundir> [seconds]      # VM Logging stream (dart:developer `log`), backlog first; default 5 s; needs websocat
#   flutter-machine.sh taint   <rundir>                # exit 1 if the run logged a tree-corruption signature, 3 if it has no log
#   flutter-machine.sh stop    <rundir>                # app.stop; ends this run's own process tree if it never started or will not exit
#
# start refuses a run directory whose tool is still alive: stop it first.
# FLUTTER overrides the launcher (default: "mise exec -- flutter", which needs
# <project-dir> to be the directory holding mise.toml, i.e. mobile/).
# Needs jq. Every message is built with jq: one malformed line on stdin crashes
# the tool with a FormatException.
set -u
cmd="${1:-}"; run="${2:-}"
usage() { awk 'NR > 1 { if (/^#/) print; else exit }' "$0"; }
[ -n "$cmd" ] && [ -n "$run" ] || { usage; exit 64; }
out="$run/run.jsonl"; ctl="$run/ctl"

field() { # event-name json-key -> first value
  grep '^\[{' "$out" 2>/dev/null | jq -r --arg e "$1" --arg k "$2" '.[] | select(.event == $e) | .params[$k] // empty' | head -1
}
alive() { [ -f "$run/pid" ] && kill -0 "$(cat "$run/pid")" 2>/dev/null; }
# True while the recorded pid is still the `flutter run --machine` this script
# started, not a process that reused the number after the run ended.
ours() { ps -o command= -p "$(cat "$run/pid" 2>/dev/null)" 2>/dev/null | grep -q -- '--machine'; }
kill_tree() { # pid signal: children first, so nothing is left to outlive its parent
  local child
  for child in $(pgrep -P "$1" 2>/dev/null); do kill_tree "$child" "$2"; done
  kill "-$2" "$1" 2>/dev/null
  return 0
}
app_id() { field app.start appId; }
app_logs() { # app.log events, plus the raw lines some devices print outside the JSON stream
  jq -Rr '(fromjson? // null) as $j | if $j == null then . elif ($j | type) == "array" then ($j[] | select(.event == "app.log") | .params.log) else empty end' "$out"
}
# Framework errors after which the widget tree may be corrupted for the rest of
# the run, so later errors can be ones no user can reach (#10439; flutter-lens §4).
taint_re="Build scheduled during frame|unfinished batch edits|while finalizing the widget tree|_debugMouseTrackerUpdateScheduled|_lifecycleState == _ElementLifecycle"
send() { # method params-json [timeout]; prints the reply line
  { alive && ours; } || { echo "flutter run is not running (see $run/run.err)" >&2; return 3; }
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
    if alive && ours; then
      echo "a run is still alive in $run (pid $(cat "$run/pid")); stop it first, or pick another run directory" >&2
      exit 3
    fi
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
  status)
    [ -f "$run/pid" ] || { echo "state=none (no run in $run)"; exit 3; }
    state=exited; alive && ours && state=running
    started=no; grep -q '"event":"app.started"' "$out" 2>/dev/null && started=yes
    echo "state=$state pid=$(cat "$run/pid") started=$started"
    echo "appId=$(app_id)"; echo "wsUri=$(field app.debugPort wsUri)"; echo "dtdUri=$(field app.dtd uri)"
    if [ "$state" != running ]; then tail -3 "$run/run.err" 2>/dev/null >&2; exit 3; fi
    [ "$started" = yes ] && exit 0
    echo "last progress: $(grep '"event":"app.progress"' "$out" 2>/dev/null | tail -1 | cut -c1-160)"; exit 1
    ;;
  reload)  send app.restart "$(jq -nc --arg a "$(app_id)" '{appId: $a, fullRestart: false, reason: "manual"}')" ;;
  restart) send app.restart "$(jq -nc --arg a "$(app_id)" '{appId: $a, fullRestart: true, reason: "manual"}')" ;;
  ext)
    name="${3:?extension name}"; params="${4:-}"; [ -n "$params" ] || params='{}'
    send app.callServiceExtension "$(jq -nc --arg a "$(app_id)" --arg n "$name" --argjson p "$params" '{appId: $a, methodName: $n, params: $p}')"
    ;;
  logs)    app_logs ;;
  vmlog)
    command -v websocat >/dev/null || { echo "vmlog needs websocat" >&2; exit 64; }
    ws=$(field app.debugPort wsUri); [ -n "$ws" ] || { echo "no wsUri yet: run '$0 wait $run' first" >&2; exit 3; }
    secs="${3:-5}"
    # DDS replays the Logging stream's history to a late subscriber, so the
    # backlog comes first. The VM cuts long strings; a cut message is marked.
    { jq -nc '{jsonrpc: "2.0", id: 1, method: "streamListen", params: {streamId: "Logging"}}'; sleep "$secs"; } \
      | perl -e 'alarm shift; exec @ARGV' "$((secs + 15))" websocat -n -E -B 50000000 "$ws" \
      | jq -r 'select(.method == "streamNotify") | .params.event | select(.kind == "Logging") | .logRecord
          | "\(.level)\t\(.loggerName.valueAsString // "-")\t\(.message.valueAsString // "")\(if .message.valueAsStringIsTruncated then " …[cut by the VM]" else "" end)"'
    ;;
  taint)
    [ -s "$out" ] || { echo "no run log at $out (missing or empty); nothing to check" >&2; exit 3; }
    hits=$(app_logs | grep -n -E "$taint_re")
    if [ -z "$hits" ]; then echo "clean: no tree-corruption signature in $(app_logs | wc -l | tr -d ' ') log lines"; exit 0; fi
    echo "TAINTED from log line $(echo "$hits" | head -1 | cut -d: -f1) ($(echo "$hits" | wc -l | tr -d ' ') matching lines): cold-start before trusting anything observed after it"
    echo "$hits" | head -3
    exit 1
    ;;
  stop)
    [ -f "$run/pid" ] || { echo "no run in $run" >&2; exit 3; }
    id=$(app_id)
    # A run that never reached app.start has no appId to stop, and would sit
    # here for the full wait: go straight to ending its process tree.
    if [ -n "$id" ]; then
      alive && ours && { send app.stop "$(jq -nc --arg a "$id" '{appId: $a}')" 30 >/dev/null || true; }
      i=0; while alive && ours && [ "$i" -lt 20 ]; do sleep 1; i=$((i + 1)); done
    fi
    if alive; then
      if ours; then
        echo "run did not exit on app.stop; ending its process tree (pid $(cat "$run/pid"))" >&2
        kill_tree "$(cat "$run/pid")" TERM
        i=0; while alive && [ "$i" -lt 5 ]; do sleep 1; i=$((i + 1)); done
        alive && kill_tree "$(cat "$run/pid")" KILL
      else
        echo "pid $(cat "$run/pid") is no longer this run's flutter process; leaving it alone" >&2
      fi
    fi
    [ -f "$run/holder.pid" ] && kill "$(cat "$run/holder.pid")" 2>/dev/null
    if alive && ours; then echo "still running; kill it by pid: $(cat "$run/pid")" >&2; exit 1; fi
    echo "stopped"
    ;;
  *) usage; exit 64 ;;
esac
