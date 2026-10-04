# Local username registry

`mise run local_up` starts the name server with the rest of the stack. LOCAL
builds use `http://10.0.2.2:43005` on Android emulator and
`http://localhost:43005` on iOS Simulator/macOS. Other environments retain
the production endpoint. If the local service is down, username requests fail
without switching to production.

This directory is a mobile-stack adapter for upstream `divine-name-server`.
The Dockerfile pins the Node image by digest and upstream source by commit and
archive checksum, then installs the upstream lockfile with `npm ci`. It copies
only package manifests, Worker source and migrations from the archive. Updating
the upstream pin requires updating the archive checksum and Compose image tag,
then rerunning the tests below. No sibling checkout or Cloudflare login is needed.

The dedicated Wrangler config has local D1/KV bindings and no production
routes, admin credentials, static assets or cron. It preserves the request's
host and published port for NIP-98 authentication. Fastly credentials are absent;
upstream logs missing sync configuration and queues retries while local D1
operations still work. These tests cover registry behavior, not production edge
propagation or complete coordinated account deletion.

Startup applies the unchanged upstream migration chain using Wrangler's
bookkeeping before serving traffic. Both processes use `/data` in the
`name-server-data` named volume. `local_down` retains usernames; `local_reset`
deletes all stack volumes, including usernames. A narrow username-only reset is:

```sh
docker compose -f local_stack/docker-compose.yml stop name-server
docker compose -f local_stack/docker-compose.yml rm -f name-server
docker volume rm local_stack_name-server-data
```

The volume name assumes the normal Compose project name; custom projects have
their own prefix. Next startup creates and migrates a fresh database.

## Signed HTTP integration test

With port 43005 free, from the repository root:

```sh
bash local_stack/test_name_server.sh
```

This builds and starts only the name server in a unique Compose project. It
checks available/reserved/taken answers, signed claims with both desktop and
Android Host headers through the Docker port mapping, rejection of mismatched
signed URLs, conflicts, by-pubkey lookup, release preparation/rollback and
persistence across restart and repeated migrations. It removes only its own
containers and disposable volume. From `mobile/`, the equivalent task is
`mise run test_local_name_server`.

## Android UI test

Start the normal stack and an Android emulator, then run from the repo root:

```sh
bash local_stack/test_username_ui.sh emulator-5554
```

The runner builds and installs a LOCAL debug app, clears that app's data through
Maestro, seeds `localtaken` with a synthetic owner, and creates a throwaway
device-only identity. It checks reserved (`admin`), taken and available names,
saves a unique claim, reopens the editor and confirms the server stored it.
The synthetic accounts and usernames remain in the local database until reset.
Maestro, adb and the repository's mise toolchain must be installed. Keep this
manual flow out of the staging smoke lane.
