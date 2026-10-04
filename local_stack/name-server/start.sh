#!/bin/sh
set -eu

# Both commands must use the same config and persistence root. Wrangler owns
# filename ordering and migration bookkeeping; repeat startup is idempotent.
./node_modules/.bin/wrangler d1 migrations apply divine-name-server-local \
  --local --config wrangler.local.toml --persist-to /data
exec ./node_modules/.bin/wrangler dev --local --config wrangler.local.toml \
  --persist-to /data --ip 0.0.0.0 --port 8787
