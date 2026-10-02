#!/usr/bin/env python3
"""Merge docker compose logs and flutter test output into sorted JSON lines."""

import json
import re
import sys
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Docker compose log line: "service-1  | 2026-03-04T13:11:56.516035573Z content"
DOCKER_RE = re.compile(
    r'^(\S+)\s+\|\s+'           # service name + pipe
    r'(\d{4}-\d{2}-\d{2}T'     # timestamp start
    r'\d{2}:\d{2}:\d{2}'       # HH:MM:SS
    r'(?:\.\d+)?Z?)\s*'        # optional fractional seconds + Z
    r'(.*)'                     # content
)

# App log with full timestamp: "[2026-03-04T15:30:00.100] ..."
APP_TS_FULL_RE = re.compile(
    r'^\[(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?)\]\s*(.*)'
)

# App log with time-only: "[11:06:55.268] ..."
APP_TS_TIME_RE = re.compile(
    r'^\[(\d{2}:\d{2}:\d{2}(?:\.\d+)?)\]\s*(.*)'
)

# Logcat line with UTC timestamps (-v UTC -v year):
# "2026-03-06 16:21:10.496 +0000  1234  5678 I flutter : message"
LOGCAT_RE = re.compile(
    r'^(\d{4}-\d{2}-\d{2}\s+\d{2}:\d{2}:\d{2}\.\d+)'  # timestamp
    r'(?:\s+[+-]\d{4})?'                                  # optional tz offset
    r'\s+\d+\s+\d+'                                       # pid tid
    r'\s+\w\s+'                                            # level
    r'(\S+)\s*:\s*'                                        # tag
    r'(.*)'                                                # message
)


def parse_ts(ts_str: str) -> str:
    """Parse various timestamp formats and return ISO 8601 string with Z suffix."""
    ts_str = re.sub(r'(\.\d{6})\d+', r'\1', ts_str)
    ts_str = ts_str.rstrip('Z')
    for fmt in ('%Y-%m-%dT%H:%M:%S.%f', '%Y-%m-%dT%H:%M:%S'):
        try:
            dt = datetime.strptime(ts_str, fmt).replace(tzinfo=timezone.utc)
            return dt.strftime('%Y-%m-%dT%H:%M:%S.%fZ')
        except ValueError:
            continue
    raise ValueError(f'Cannot parse timestamp: {ts_str}')


def parse_docker_logs(path: Path) -> tuple[list[dict], str]:
    """Parse docker compose log file into structured entries.

    Returns (entries, date_prefix) where date_prefix is the date
    from the first docker timestamp (e.g. '2026-03-04') for use
    in normalizing time-only app log timestamps.
    """
    entries = []
    date_prefix = ''
    for line in path.read_text(errors="replace").splitlines():
        if not line.strip():
            continue
        m = DOCKER_RE.match(line)
        if m:
            service = m.group(1).rsplit('-', 1)[0]
            try:
                ts = parse_ts(m.group(2))
            except ValueError:
                continue
            if not date_prefix:
                date_prefix = ts[:10]
            entries.append({
                'ts': ts,
                'source': service,
                'line': m.group(3).strip(),
            })
    return entries, date_prefix


def parse_app_logs(path: Path, date_prefix: str) -> list[dict]:
    """Parse flutter test stdout into structured entries.

    Uses [date_prefix] (e.g. '2026-03-04') to normalize time-only
    timestamps like [11:06:55.268] into full ISO 8601 timestamps.
    """
    entries = []
    for line in path.read_text(errors="replace").splitlines():
        if not line.strip():
            continue
        m = APP_TS_FULL_RE.match(line)
        if m:
            try:
                ts = parse_ts(m.group(1))
            except ValueError:
                continue
            entries.append({
                'ts': ts,
                'source': 'app',
                'line': m.group(2).strip(),
            })
            continue
        m = APP_TS_TIME_RE.match(line)
        if m and date_prefix:
            try:
                ts = parse_ts(f'{date_prefix}T{m.group(1)}')
            except ValueError:
                continue
            entries.append({
                'ts': ts,
                'source': 'app',
                'line': m.group(2).strip(),
            })
            continue
        entries.append({
            'ts': '',
            'source': 'app',
            'line': line.strip(),
        })
    return entries


def _parse_iso(ts_str: str) -> datetime:
    """Parse an ISO 8601 timestamp string back into a datetime."""
    return datetime.strptime(
        ts_str, '%Y-%m-%dT%H:%M:%S.%fZ',
    ).replace(tzinfo=timezone.utc)


def parse_logcat_logs(path: Path) -> list[dict]:
    """Parse Android logcat output (captured with -v UTC -v year)."""
    entries = []
    for line in path.read_text(errors="replace").splitlines():
        if not line.strip():
            continue
        m = LOGCAT_RE.match(line)
        if m:
            ts_raw = m.group(1).replace(' ', 'T')
            try:
                ts = parse_ts(ts_raw)
            except ValueError:
                continue
            tag = m.group(2)
            msg = m.group(3).strip()
            entries.append({
                'ts': ts,
                'source': f'app:{tag}' if tag != 'flutter' else 'app',
                'line': msg,
            })
    return entries


def normalize_app_utc_offset(
    docker_entries: list[dict],
    app_entries: list[dict],
) -> timedelta:
    """Detect local-vs-UTC offset between app and docker timestamps.

    Compares the first timestamped entry from each source, rounds the
    difference to the nearest 30 minutes (covers all real timezones),
    and returns the offset to add to app timestamps.

    Returns timedelta(0) if offset cannot be determined.
    """
    first_docker = next(
        (e for e in docker_entries if e['ts']), None,
    )
    first_app = next((e for e in app_entries if e['ts']), None)
    if not first_docker or not first_app:
        return timedelta(0)

    dt_docker = _parse_iso(first_docker['ts'])
    dt_app = _parse_iso(first_app['ts'])
    diff = dt_docker - dt_app
    diff_seconds = diff.total_seconds()

    # Round to nearest 30 minutes (1800s)
    rounded = round(diff_seconds / 1800) * 1800
    if abs(rounded) < 1800:
        return timedelta(0)

    return timedelta(seconds=rounded)


def apply_offset(entries: list[dict], offset: timedelta) -> None:
    """Shift all timestamps in entries by offset (in place)."""
    if offset == timedelta(0):
        return
    for e in entries:
        if e['ts']:
            dt = _parse_iso(e['ts']) + offset
            e['ts'] = dt.strftime('%Y-%m-%dT%H:%M:%S.%fZ')


def main():
    if len(sys.argv) < 4:
        print(
            f'Usage: {sys.argv[0]} <docker_log> <logcat_log> <patrol_log> <output>',
            file=sys.stderr,
        )
        sys.exit(1)

    docker_path = Path(sys.argv[1])
    logcat_path = Path(sys.argv[2])
    patrol_path = Path(sys.argv[3])
    output_path = Path(sys.argv[4]) if len(sys.argv) > 4 else None

    docker_entries, date_prefix = parse_docker_logs(docker_path)
    if not date_prefix:
        date_prefix = datetime.now(tz=timezone.utc).strftime('%Y-%m-%d')

    logcat_entries = parse_logcat_logs(logcat_path)
    patrol_entries = parse_app_logs(patrol_path, date_prefix)

    # Normalize app timestamps from local time to UTC
    app_entries = logcat_entries + patrol_entries
    offset = normalize_app_utc_offset(docker_entries, app_entries)
    if offset != timedelta(0):
        hours = offset.total_seconds() / 3600
        print(f'Detected app→UTC offset: {hours:+.1f}h', file=sys.stderr)
        apply_offset(app_entries, offset)

    all_entries = docker_entries + app_entries
    all_entries.sort(key=lambda e: e['ts'] if e['ts'] else 'z')

    lines = [json.dumps(e) for e in all_entries]
    output = '\n'.join(lines) + '\n'

    if output_path:
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(output)
        print(f'Wrote {len(all_entries)} entries to {output_path}',
              file=sys.stderr)
    else:
        sys.stdout.write(output)


if __name__ == '__main__':
    main()
