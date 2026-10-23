#!/usr/bin/env python3
"""Execute the real report against synthetic BigQuery rows, with zero scan budget."""
from pathlib import Path
import subprocess

report = Path(__file__).resolve().parents[2] / 'docs/analytics/push_engagement.sql'
sql = report.read_text()
prefix, rest = sql.split('-- BEGIN GA4 SOURCE', 1)
_, suffix = rest.split('-- END GA4 SOURCE', 1)
prefix = prefix.replace(
    "DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 31 DAY)", "DATE '2026-10-01'"
).replace("DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 4 DAY)", "DATE '2026-10-01'")
rows = [
    ('a', 1, 2, '12:00:00', 'session_start', 0, None),
    ('a', 1, 2, '12:00:10', 'user_engagement', 10000, None),
    ('a', 1, 2, '12:00:15', 'publish_succeeded', 0, None),
    ('a', 1, 2, '12:00:20', 'push_notification_opened', 0, 'comment'),
    ('a', 1, 2, '12:00:25', 'user_engagement', 10000, None),
    ('a', 1, 2, '12:00:26', 'publish_succeeded', 0, None),
    ('a', 2, 3, '19:00:00', 'session_start', 0, None),
    ('b', 3, 1, '12:30:00', 'push_notification_opened', 0, 'campaign'),
    ('c', 4, 3, '13:00:00', 'session_start', 0, None),
    ('c', 4, 3, '13:00:20', 'user_engagement', 20000, None),
    ('d', 5, None, '14:00:00', 'session_start', 0, None),
    ('e', 6, 2, '2026-10-01 23:59:00', 'session_start', 0, None),
    ('e', 6, 2, '2026-10-02 00:01:00', 'push_notification_opened', 0, 'like'),
    ('e', 6, 2, '2026-10-02 00:02:00', 'user_engagement', 60000, None),
    ('e', 6, 2, '2026-10-02 00:02:00', 'publish_succeeded', 0, None),
    ('e', 6, 2, '2026-10-03 00:00:00', 'publish_succeeded', 0, None),
]
structs = []
for user, session, number, time, event, engagement, kind in rows:
    timestamp = time if ' ' in time else '2026-10-01 ' + time
    number_sql = 'CAST(NULL AS INT64)' if number is None else str(number)
    kind_sql = 'CAST(NULL AS STRING)' if kind is None else repr(kind)
    structs.append(
        f"STRUCT('fixture-{user}' AS user_pseudo_id, {session} AS session_id, "
        f"{number_sql} AS session_number, 'IOS' AS platform, "
        f"UNIX_MICROS(TIMESTAMP '{timestamp}+00') AS event_timestamp, "
        f"'{event}' AS event_name, {engagement} AS engagement_time_msec, "
        f"{kind_sql} AS notification_type)"
    )
fixture = 'CREATE TEMP TABLE raw_events AS SELECT * FROM UNNEST([\n'
fixture += ',\n'.join(structs) + '\n]);\n'
assertions = """
ASSERT (SELECT sessions FROM report WHERE notification_type = 'all') = 6 AS 'all sessions';
ASSERT (SELECT users FROM report WHERE notification_type = 'all') = 5 AS 'deduplicate users across sessions';
ASSERT (SELECT returning_sessions FROM report WHERE notification_type = 'all') = 4 AS 'returning sessions';
ASSERT (SELECT returning_users FROM report WHERE notification_type = 'all') = 3 AS 'returning users';
ASSERT (SELECT sessions_missing_return_status FROM report WHERE notification_type = 'all') = 1 AS 'unknown return status';
ASSERT (SELECT notification_opens FROM report WHERE notification_type = 'all') = 3 AS 'opens';
ASSERT (SELECT sessions_with_notification_open FROM report WHERE notification_type = 'all') = 3 AS 'attributed sessions';
ASSERT (SELECT engagement_seconds FROM report WHERE notification_type = 'all') = 100 AS 'engagement total';
ASSERT (SELECT post_open_engagement_seconds FROM report WHERE notification_type = 'all') = 65 AS 'exclude engagement before tap including straddling interval';
ASSERT (SELECT observed_publishes FROM report WHERE notification_type = 'all') = 3 AS 'all publish events';
ASSERT (SELECT post_open_publishes FROM report WHERE notification_type = 'all') = 2 AS 'exclude publishes before tap';
ASSERT (SELECT sessions FROM report WHERE notification_type = 'comment') = 1 AS 'first notification type';
ASSERT (SELECT notification_opens FROM report WHERE notification_type = 'like') = 1 AS 'final-day session keeps its next-day tap';
ASSERT (SELECT post_open_publishes FROM report WHERE notification_type = 'like') = 1 AS 'final-day session keeps next-day publish but excludes upper boundary';
ASSERT (SELECT session_date FROM report WHERE notification_type = 'like') = DATE '2026-10-01' AS 'cross-midnight session belongs to start date';
"""
result = subprocess.run(
    ['bq', 'query', '--project_id=openvine-co', '--use_legacy_sql=false',
     '--maximum_bytes_billed=0', '--format=none'],
    input=prefix + fixture + suffix + assertions, text=True, capture_output=True,
)
if result.returncode:
    raise SystemExit(result.stderr + result.stdout)
print('PASS: 15 synthetic report assertions; no production tables scanned.')
