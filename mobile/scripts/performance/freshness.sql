-- Run first. An empty or stale export cannot establish that a release is healthy.
WITH observed AS (
  SELECT _TABLE_SUFFIX AS platform, MAX(_PARTITIONDATE) AS latest_partition,
    MAX(event_timestamp) AS latest_event, COUNT(*) AS rows_in_window
  FROM `openvine-co.firebase_performance.co_openvine_app_*`
  WHERE _TABLE_SUFFIX IN ('IOS', 'ANDROID')
    AND _PARTITIONDATE BETWEEN @start_date AND DATE_ADD(@end_date, INTERVAL 7 DAY)
  GROUP BY platform
)
SELECT platform, latest_partition, latest_event,
  DATE(latest_event, 'America/Los_Angeles') AS latest_console_day,
  TIMESTAMP_DIFF(CURRENT_TIMESTAMP(), latest_event, HOUR) AS event_age_hours,
  COALESCE(rows_in_window, 0) AS rows_in_window,
  COALESCE(DATE(latest_event, 'America/Los_Angeles') >= @end_date, FALSE) AS reaches_requested_end_day
FROM UNNEST(['IOS', 'ANDROID']) AS platform
LEFT JOIN observed USING (platform);
