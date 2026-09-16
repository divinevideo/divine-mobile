-- Named DATE parameters: start_date, end_date. Inclusive console-local dates.
-- Seven ingestion days of headroom accommodate delayed client uploads/exports.
WITH requests AS (
  SELECT _TABLE_SUFFIX AS platform, app_display_version, app_build_version,
    CASE
      WHEN REGEXP_CONTAINS(event_name, r'^https?://moderation-api\.divine\.video(?::[0-9]+)?/api/delete-status/') THEN 'creator_delete_status'
      WHEN REGEXP_CONTAINS(event_name, r'^https?://moderation-api\.divine\.video(?::[0-9]+)?/api/delete/') THEN 'creator_delete'
      WHEN REGEXP_CONTAINS(event_name, r'^https?://moderation-api\.divine\.video(?::[0-9]+)?/check-result(?:/|$|\?)') THEN 'moderation_lookup'
      WHEN REGEXP_CONTAINS(event_name, r'^https?://moderation-api\.divine\.video(?::[0-9]+)?/') THEN 'moderation_other'
      ELSE 'other'
    END AS operation,
    network_info.request_http_method AS method,
    network_info.response_code AS status,
    network_info.response_completed_time_us / 1000.0 AS duration_ms
  FROM `openvine-co.firebase_performance.co_openvine_app_*`
  WHERE _TABLE_SUFFIX IN ('IOS', 'ANDROID')
    AND _PARTITIONDATE BETWEEN @start_date AND DATE_ADD(@end_date, INTERVAL 7 DAY)
    AND DATE(event_timestamp, 'America/Los_Angeles') BETWEEN @start_date AND @end_date
    AND event_type = 'NETWORK_REQUEST'
)
SELECT platform, app_display_version, app_build_version, operation, method,
  COUNT(*) AS samples,
  COUNT(*) >= 100 AS enough_samples_to_compare,
  COUNTIF(status BETWEEN 200 AND 399) AS successes,
  COUNTIF(status = 404) AS not_found,
  COUNTIF(status = 429) AS rate_limited,
  COUNTIF(status >= 500) AS server_errors,
  COUNTIF(status IS NULL OR status <= 0) AS no_response,
  SAFE_DIVIDE(COUNTIF(status BETWEEN 200 AND 399), COUNT(*)) AS success_ratio,
  APPROX_QUANTILES(duration_ms, 100)[OFFSET(50)] AS all_p50_ms,
  APPROX_QUANTILES(duration_ms, 100)[OFFSET(90)] AS all_p90_ms,
  APPROX_QUANTILES(duration_ms, 100)[OFFSET(99)] AS all_p99_ms,
  APPROX_QUANTILES(IF(status BETWEEN 200 AND 399, duration_ms, NULL), 100)[OFFSET(90)] AS success_p90_ms,
  APPROX_QUANTILES(IF(status = 404, duration_ms, NULL), 100)[OFFSET(90)] AS not_found_p90_ms
FROM requests
GROUP BY platform, app_display_version, app_build_version, operation, method
ORDER BY platform, operation, method, app_build_version;
