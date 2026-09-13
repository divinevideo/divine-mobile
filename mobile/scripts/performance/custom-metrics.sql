-- Select measured metrics for startup/playback; their trace durations are NOT
-- startup or first-frame latency. Metric rows are not an operation denominator.
WITH samples AS (
  SELECT _TABLE_SUFFIX AS platform, app_display_version, app_build_version,
    parent_trace_name AS trace, event_name AS metric,
    trace_info.metric_info.metric_value AS value,
    (SELECT value FROM UNNEST(custom_attributes) WHERE key = 'operation' LIMIT 1) AS operation,
    (SELECT value FROM UNNEST(custom_attributes) WHERE key = 'outcome' LIMIT 1) AS outcome,
    (SELECT value FROM UNNEST(custom_attributes) WHERE key = 'phase' LIMIT 1) AS phase,
    (SELECT value FROM UNNEST(custom_attributes) WHERE key = 'milestone' LIMIT 1) AS milestone,
    (SELECT value FROM UNNEST(custom_attributes) WHERE key = 'cache' LIMIT 1) AS cache
  FROM `openvine-co.firebase_performance.co_openvine_app_*`
  WHERE _TABLE_SUFFIX IN ('IOS', 'ANDROID')
    AND _PARTITIONDATE BETWEEN @start_date AND DATE_ADD(@end_date, INTERVAL 7 DAY)
    AND DATE(event_timestamp, 'America/Los_Angeles') BETWEEN @start_date AND @end_date
    AND event_type = 'TRACE_METRIC'
    AND (parent_trace_name IN ('http_operation', 'creator_delete_enforcement',
      'startup_phase', 'startup_milestone', 'video_first_frame',
      'video_publish', 'video_generation', 'camera_startup', 'video_upload', 'video_upload_enqueue') OR STARTS_WITH(parent_trace_name, 'feed_load_'))
)
SELECT platform, app_display_version, app_build_version, trace, metric,
  operation, outcome, phase, milestone, cache,
  COUNT(*) AS samples, COUNT(*) >= 100 AS enough_samples_to_compare,
  APPROX_QUANTILES(value, 100)[OFFSET(50)] AS p50,
  APPROX_QUANTILES(value, 100)[OFFSET(90)] AS p90,
  APPROX_QUANTILES(value, 100)[OFFSET(99)] AS p99
FROM samples
GROUP BY platform, app_display_version, app_build_version, trace, metric,
  operation, outcome, phase, milestone, cache
ORDER BY platform, trace, metric, app_build_version;
