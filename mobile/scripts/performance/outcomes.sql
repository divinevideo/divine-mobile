-- DURATION_TRACE only: one completed trace sample per operation, not one per
-- metric. Firebase sampling means these are observed samples, not exact traffic.
WITH samples AS (
  SELECT _TABLE_SUFFIX AS platform, app_display_version, app_build_version,
    event_name AS trace,
    (SELECT value FROM UNNEST(custom_attributes) WHERE key = 'operation' LIMIT 1) AS operation,
    (SELECT value FROM UNNEST(custom_attributes) WHERE key = 'outcome' LIMIT 1) AS outcome,
    (SELECT value FROM UNNEST(custom_attributes) WHERE key = 'reason' LIMIT 1) AS reason,
    trace_info.duration_us / 1000.0 AS duration_ms
  FROM `openvine-co.firebase_performance.co_openvine_app_*`
  WHERE _TABLE_SUFFIX IN ('IOS', 'ANDROID')
    AND _PARTITIONDATE BETWEEN @start_date AND DATE_ADD(@end_date, INTERVAL 7 DAY)
    AND DATE(event_timestamp, 'America/Los_Angeles') BETWEEN @start_date AND @end_date
    AND event_type = 'DURATION_TRACE'
    AND (event_name IN ('http_operation', 'creator_delete_enforcement',
      '_app_start', 'video_publish', 'video_generation', 'camera_startup', 'video_upload', 'video_upload_enqueue')
      OR STARTS_WITH(event_name, 'feed_load_'))
)
SELECT platform, app_display_version, app_build_version, trace, operation,
  outcome, reason, COUNT(*) AS samples,
  SUM(COUNT(*)) OVER (PARTITION BY platform, app_display_version, app_build_version, trace, operation) AS operation_samples,
  SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER (PARTITION BY platform, app_display_version, app_build_version, trace, operation)) AS outcome_share,
  APPROX_QUANTILES(duration_ms, 100)[OFFSET(90)] AS p90_duration_ms
FROM samples
GROUP BY platform, app_display_version, app_build_version, trace, operation, outcome, reason
ORDER BY platform, trace, operation, app_build_version, outcome;
