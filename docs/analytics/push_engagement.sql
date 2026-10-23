-- Descriptive notification attribution and return-use trends. No experiment.
-- Closed daily exports only; timestamps and report dates are UTC.
DECLARE start_date DATE DEFAULT DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 31 DAY);
-- end_date + 1 is observed too, so it also needs GA4's 72-hour late-event window.
DECLARE end_date DATE DEFAULT DATE_SUB(CURRENT_DATE('UTC'), INTERVAL 4 DAY);
ASSERT start_date <= end_date AS 'start_date must not exceed end_date';
ASSERT DATE_DIFF(end_date, start_date, DAY) < 90 AS 'report window must be under 90 days';

-- BEGIN GA4 SOURCE
CREATE TEMP TABLE raw_events AS
SELECT
  user_pseudo_id,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_id') AS session_id,
  (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'ga_session_number') AS session_number,
  platform,
  event_timestamp,
  event_name,
  GREATEST(COALESCE(
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engagement_time_msec'), 0
  ), 0) AS engagement_time_msec,
  (SELECT value.string_value FROM UNNEST(event_params) WHERE key = 'notification_type') AS notification_type
FROM `openvine-co.analytics_505815521.events_*`
WHERE _TABLE_SUFFIX BETWEEN FORMAT_DATE('%Y%m%d', DATE_SUB(start_date, INTERVAL 1 DAY))
                        AND FORMAT_DATE('%Y%m%d', DATE_ADD(end_date, INTERVAL 2 DAY))
  AND REGEXP_CONTAINS(_TABLE_SUFFIX, r'^\d{8}$')
  AND platform IN ('IOS', 'ANDROID');
-- END GA4 SOURCE

CREATE TEMP TABLE report AS
-- Observe the following UTC day so final-day sessions keep post-midnight taps.
WITH session_events AS (
  SELECT * FROM raw_events
  WHERE user_pseudo_id IS NOT NULL AND session_id > 0
    AND event_timestamp >= UNIX_MICROS(TIMESTAMP(DATE_SUB(start_date, INTERVAL 1 DAY), 'UTC'))
    AND event_timestamp < UNIX_MICROS(TIMESTAMP(DATE_ADD(end_date, INTERVAL 2 DAY), 'UTC'))
), summaries AS (
  SELECT
    user_pseudo_id, session_id, platform,
    DATE(TIMESTAMP_MICROS(COALESCE(
      MIN(IF(event_name = 'session_start', event_timestamp, NULL)),
      MIN(event_timestamp)
    )), 'UTC') AS session_date,
    MAX(session_number) AS session_number,
    MIN(IF(event_name = 'push_notification_opened', event_timestamp, NULL)) AS first_push_open_at,
    COALESCE(ARRAY_AGG(
      IF(event_name = 'push_notification_opened', COALESCE(notification_type, 'unknown'), NULL)
      IGNORE NULLS ORDER BY event_timestamp LIMIT 1
    )[SAFE_OFFSET(0)], 'none') AS notification_type
  FROM session_events
  GROUP BY user_pseudo_id, session_id, platform
), session_metrics AS (
  SELECT
    s.*,
    COUNTIF(e.event_name = 'push_notification_opened') AS notification_opens,
    SUM(e.engagement_time_msec) AS engagement_time_msec,
    -- Engagement time describes an interval ending at the event timestamp.
    -- Clip intervals straddling the first tap instead of crediting pre-tap time.
    SUM(IF(e.event_timestamp >= s.first_push_open_at,
      LEAST(e.engagement_time_msec,
        GREATEST(DIV(e.event_timestamp - s.first_push_open_at, 1000), 0)), 0
    )) AS post_open_engagement_time_msec,
    COUNTIF(e.event_name = 'publish_succeeded') AS observed_publishes,
    COUNTIF(e.event_name = 'publish_succeeded'
      AND e.event_timestamp >= s.first_push_open_at) AS post_open_publishes
  FROM summaries s
  JOIN session_events e USING (user_pseudo_id, session_id, platform)
  GROUP BY s.user_pseudo_id, s.session_id, s.platform, s.session_date,
           s.session_number, s.first_push_open_at, s.notification_type
)
SELECT
  session_date, platform,
  IF(GROUPING(m.notification_type) = 1, 'all', m.notification_type) AS notification_type,
  COUNT(*) AS sessions,
  COUNT(DISTINCT user_pseudo_id) AS users,
  COUNTIF(session_number > 1) AS returning_sessions,
  COUNT(DISTINCT IF(session_number > 1, user_pseudo_id, NULL)) AS returning_users,
  COUNTIF(session_number IS NULL) AS sessions_missing_return_status,
  SAFE_DIVIDE(COUNTIF(session_number > 1), COUNTIF(session_number IS NOT NULL)) AS returning_session_share,
  SUM(notification_opens) AS notification_opens,
  COUNTIF(first_push_open_at IS NOT NULL) AS sessions_with_notification_open,
  SUM(engagement_time_msec) / 1000.0 AS engagement_seconds,
  SUM(post_open_engagement_time_msec) / 1000.0 AS post_open_engagement_seconds,
  SUM(observed_publishes) AS observed_publishes,
  SUM(post_open_publishes) AS post_open_publishes
FROM session_metrics AS m
WHERE session_date BETWEEN start_date AND end_date
GROUP BY GROUPING SETS (
  (session_date, platform),
  (session_date, platform, m.notification_type)
);

SELECT * FROM report ORDER BY session_date, platform, notification_type;
