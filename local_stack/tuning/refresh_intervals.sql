-- Shorten the refreshable-materialized-view intervals that local development
-- and the e2e suite depend on.
--
-- WHY
--
-- funnelcake serves several read models out of snapshot tables fed by
-- refreshable MVs rather than querying live. On production cadences those
-- snapshots rebuild every 5-60 minutes, which is correct there and useless
-- locally: a video published now is invisible to `GET /api/users/{pubkey}/videos`
-- until the next rebuild.
--
-- Measured on a stack built from funnelcake main (2026-08-07): 110 kind-34236
-- events sat in `nostr.events_local` while `SELECT count() FROM nostr.video_stats`
-- returned 0, with `next_refresh_time` 4.5 minutes out. `video_stats` stopped
-- being a live view at migration 000143 (`DROP VIEW nostr.video_stats` ->
-- `CREATE VIEW ... FROM nostr.video_stats_snapshot`, initially 60s) and its MV
-- was widened to `REFRESH EVERY 15 MINUTE OFFSET 3 MINUTE` by 000182/000184.
--
-- integration_test/helpers/http_helpers.dart polls that endpoint with
-- `maxSeconds = 30`, so deleted_video_visible_to_other_users_test.dart fails at
-- its first phase without this. After the ALTER below a freshly published video
-- appeared within ~10 seconds.
--
-- SCOPE
--
-- Only the MVs local development actually needs for publish/read visibility.
-- A current database has many refreshable MVs; blanket-shortening all of them
-- would make a laptop churn on recomputes for read models nothing here touches.

-- The read model behind GET /api/users/{pubkey}/videos. Required by the e2e.
ALTER TABLE nostr.video_stats_snapshot_refresh_mv MODIFY REFRESH EVERY 10 SECOND;

-- Feed read models, so a developer poking at the app sees their own writes.
ALTER TABLE nostr.popular_videos_snapshot_refresh_mv MODIFY REFRESH EVERY 30 SECOND;
ALTER TABLE nostr.trending_videos_snapshot_refresh_mv MODIFY REFRESH EVERY 30 SECOND;
ALTER TABLE nostr.user_feed_video_candidates_refresh_mv MODIFY REFRESH EVERY 30 SECOND;

-- DELIBERATELY NOT SHORTENED: recent_videos_snapshot_refresh_mv.
--
-- Migration 000257 removed this view and its destination table when the relay
-- feed switched to publication-order pagination. Keeping its old ALTER here
-- would make every current local startup report a misleading skipped tuning.

-- DELIBERATELY NOT SHORTENED: relay_feed_cache_refresh_mv.
--
-- This MV backs the bare default relay feed cache, not the REST
-- `/api/users/{pubkey}/videos` path the e2e polls. It is also the heaviest MV in
-- current funnelcake: 000205 widened it to `REFRESH EVERY 1 HOUR OFFSET 6
-- MINUTE` after ClickHouse Inc. measured it at ~19 GiB per 15-minute refresh.
-- Shortening it to seconds makes a 100-event seed feel instant, but it reverses
-- four production widenings for a path the local acceptance test does not need.

-- DELIBERATELY NOT SHORTENED: video_event_card_snapshot_refresh_mv.
--
-- Shortening it buys nothing. It reads `nostr.classic_videos_snapshot`
-- (000170:642), whose only writer is classic_videos_snapshot_refresh_mv at
-- 10 minutes (000182:47), which is not in the list above. Setting the card MV
-- to 10s would just make it free-run against a source that still rebuilds
-- every 10 minutes. Nothing in local dev reads it either — the e2e polls
-- `/api/users/{pubkey}/videos`, which is the video_stats path.
--
-- It is also the one MV that was given an ordering guarantee:
-- `DEPENDS ON nostr.classic_videos_snapshot_refresh_mv` (000170:620), the only
-- DEPENDS ON in the schema. 000184 warns that "MODIFY REFRESH replaces ALL
-- refresh parameters, so touching it would silently drop that dependency."
-- Worth knowing that upstream already tripped this: 000182:50 ran exactly that
-- ALTER, so the clause is gone by schema 210 — `SELECT create_table_query`
-- shows `REFRESH EVERY 10 MINUTE TO ...` with no DEPENDS ON, and nothing after
-- 000182 restores it. Re-altering it here would not restore it either, and
-- would only add churn, so leave it alone.
--
-- The ALTERs above intentionally replace the production `EVERY ... OFFSET`
-- schedules from 000184. That is acceptable only because this file is local
-- tuning: those minute-scale offsets cannot be preserved with 10s/30s local
-- periods, and avoiding long local staleness is the point. Do not copy these
-- ALTERs into funnelcake production migrations; there, every refresh edit must
-- restate the full EVERY/OFFSET schedule as 000184 requires.
