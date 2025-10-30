# Backend Issue Report: Cloudflare Worker Error 1042

**Date**: 2025-10-07
**Reporter**: Flutter Team
**Severity**: CRITICAL - Blocking all video uploads
**Status**: Production worker completely offline

---

## Issue Summary

The Cloudflare Worker at `cf-stream-service-prod.protestnet.workers.dev` is returning **error code 1042** for all requests, including both the root endpoint and the `/upload` endpoint.

**Cloudflare Error 1042** = "Origin Offline" or "Connection Timed Out"

This indicates the Worker is deployed but either:
- Crashing on initialization
- Timing out on all requests
- Unable to connect to backend dependencies (R2, KV, etc.)

---

## Reproduction Steps

### 1. Test Root Endpoint
```bash
curl https://cf-stream-service-prod.protestnet.workers.dev/
```

**Expected**: Some response (404, 200, etc.)
**Actual**: `error code: 1042`

### 2. Test Upload Endpoint with PUT
```bash
curl -X PUT https://cf-stream-service-prod.protestnet.workers.dev/upload \
  -H "Content-Type: video/mp4" \
  -v
```

**Expected**: Auth error (401) or success (200)
**Actual**: `error code: 1042`

### 3. Check HTTP Status
```bash
curl -I https://cf-stream-service-prod.protestnet.workers.dev/
```

**Result**: `HTTP/2 404` with body `error code: 1042`

---

## Flutter Client Status

✅ **Flutter client is correctly implemented**:
- Using PUT method (not POST)
- Sending raw binary data as `Stream<List<int>>`
- Including proper headers:
  - `Authorization: Nostr <base64-event>`
  - `Content-Type: video/mp4`
  - `Content-Length: <bytes>`
- Creating valid Blossom auth event (kind 24242)

**Evidence from Flutter logs**:
```
[VIDEO] Uploading using Blossom spec (PUT with raw bytes)
[VIDEO] File hash: 4611610af986f6809260aaf61ab2961b7bbc8fc626e361709546be031b23d691
[VIDEO] Sending PUT request with raw video bytes
[VIDEO]   URL: https://cf-stream-service-prod.protestnet.workers.dev/upload
[VIDEO]   File size: 93061 bytes
[VIDEO] Blossom server response: 404
[VIDEO] Response data: error code: 1042
```

The Flutter client is doing everything correctly - the issue is entirely server-side.

---

## Required Backend Investigation

### 1. Check Cloudflare Worker Logs
```bash
# View recent logs
wrangler tail cf-stream-service-prod

# Or check dashboard logs
https://dash.cloudflare.com/
```

**Look for**:
- Uncaught exceptions during worker initialization
- Timeout errors
- R2/KV binding errors
- Import/dependency errors

### 2. Verify Worker Deployment
```bash
# Check current deployment
wrangler deployments list

# Verify worker is actually deployed
wrangler whoami
wrangler status
```

**Confirm**:
- Latest code is deployed
- No failed deployments
- Worker is in "running" state

### 3. Check Worker Configuration

**In `wrangler.toml`**, verify:
```toml
[[r2_buckets]]
binding = "R2_BUCKET"
bucket_name = "your-bucket-name"

[[kv_namespaces]]
binding = "KV"
id = "your-kv-namespace-id"
```

**Check**:
- R2 bucket exists and is accessible
- KV namespace exists and is bound correctly
- All environment variables are set

### 4. Test Worker Routes

According to previous code review, the worker should have these routes:
- `PUT /upload` - Blossom upload handler
- `GET /<sha256>` - Retrieve blob by hash
- `HEAD /<sha256>` - Check if blob exists
- `DELETE /<sha256>` - Delete blob
- `GET /list/<pubkey>` - List user's blobs

**Test if ANY route works**:
```bash
# Try different endpoints
curl https://cf-stream-service-prod.protestnet.workers.dev/list/test
curl https://cf-stream-service-prod.protestnet.workers.dev/test123
```

### 5. Check for Worker Errors

Common causes of error 1042:
- **Initialization timeout**: Worker taking >30s to start
- **Uncaught exception**: Error thrown outside request handler
- **Missing binding**: R2/KV binding not configured
- **Dependency error**: Module import failing
- **Resource limit**: Worker exceeding memory/CPU limits

---

## Expected Worker Behavior

### For Root `/` Endpoint:
Should either:
- Return 404 with custom message (if no root handler)
- Return 200 with API info (if root handler exists)
- **Should NOT** return error 1042

### For `/upload` Endpoint with PUT:
Should either:
- Return 401 (Unauthorized) if no auth header
- Return 400 (Bad Request) if invalid auth
- Return 200/201 with JSON on success
- **Should NOT** return error 1042

---

## Testing After Fix

Once the worker is fixed, test with:

```bash
# 1. Create test file
echo "test data" > test.mp4

# 2. Calculate hash
FILE_HASH=$(shasum -a 256 test.mp4 | awk '{print $1}')
echo "Hash: $FILE_HASH"

# 3. Test PUT (will get auth error but should not get 1042)
curl -X PUT \
  https://cf-stream-service-prod.protestnet.workers.dev/upload \
  -H "Content-Type: video/mp4" \
  -H "Content-Length: $(wc -c < test.mp4)" \
  --data-binary @test.mp4 \
  -v

# Expected: 401 Unauthorized (not 1042)
```

---

## Success Criteria

✅ Worker responds to root `/` without error 1042
✅ PUT `/upload` returns 401 (auth error) instead of 1042
✅ Worker logs show no initialization errors
✅ All R2/KV bindings working

---

## Additional Context

### Previous Working State
The worker was previously responding with HTTP 404 `{error: not_found}` for POST requests, which indicated it was running but didn't have the POST handler configured. That was a routing issue.

Now it's returning error 1042, which indicates the worker itself is not running properly.

### Change History
- **Before**: Worker running, POST not supported → returned `{error: not_found}`
- **Now**: Worker offline/crashed → returns `error code: 1042`

Something changed in the backend deployment that broke the entire worker.

---

## Contact

For questions about Flutter client implementation: Flutter Team
For backend/worker questions: Backend Team

**This is blocking all video uploads in production.**
