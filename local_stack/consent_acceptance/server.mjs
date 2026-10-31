// Local-only contract harness: the unmodified backend runs with real D1/R2.
// External ticketing, signing-key projection and Access identity are synthetic.
import { createRequire } from 'node:module';
import { createServer } from 'node:http';
import { createHash, generateKeyPairSync, sign } from 'node:crypto';
import { mkdtemp, readFile, readdir, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';

const backend = resolve(process.argv[2]);
const pin = JSON.parse(await readFile(new URL('./backend-pin.json', import.meta.url), 'utf8'));
async function sourceFiles(directory) {
  const entries = await readdir(join(backend, directory), { withFileTypes: true });
  return (await Promise.all(entries.map(entry => entry.isDirectory()
    ? sourceFiles(`${directory}/${entry.name}`)
    : entry.name.endsWith('.ts') ? [`${directory}/${entry.name}`] : []))).flat();
}
const files = [...await sourceFiles('worker/src'), ...await sourceFiles('shared'),
  'worker/package.json', 'worker/package-lock.json'].sort();
const digest = createHash('sha256');
for (const file of files) digest.update(file).update('\0').update(await readFile(join(backend, file))).update('\0');
if (digest.digest('hex') !== pin.sha256) throw new Error(`Backend source does not match pinned candidate ${pin.commit}`);
const require = createRequire(join(backend, 'worker/package.json'));
const { build } = require('esbuild');
const { Miniflare } = require('miniflare');
const { nip19 } = require('nostr-tools');
const syntheticAdminKey = new Uint8Array(32);
syntheticAdminKey[31] = 3;
const output = await mkdtemp(join(tmpdir(), 'consent-worker-'));
await build({
  entryPoints: [join(backend, 'worker/src/index.ts')],
  outfile: join(output, 'worker.mjs'),
  bundle: true, format: 'esm', platform: 'browser', target: 'es2022',
});
const { publicKey, privateKey } = generateKeyPairSync('rsa', { modulusLength: 2048 });
const jwk = { ...publicKey.export({ format: 'jwk' }), kid: 'local-consent', alg: 'RS256', use: 'sig' };
const comments = [];
const outbound = [];
const unexpected = [];
let ticketId = 100;
const json = (value, status = 200) => new Response(JSON.stringify(value), {
  status, headers: { 'content-type': 'application/json' },
});
function accessToken(overrides = {}) {
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  const message = `${encode({ alg: 'RS256', kid: jwk.kid })}.${encode({
    iss: 'https://consent-access.test', aud: ['consent-local'],
    exp: Math.floor(Date.now() / 1000) + 300, ...overrides,
  })}`;
  return `${message}.${sign('RSA-SHA256', Buffer.from(message), privateKey).toString('base64url')}`;
}
const mf = new Miniflare({
  modules: true, modulesRoot: output, scriptPath: join(output, 'worker.mjs'),
  compatibilityDate: '2024-12-01', compatibilityFlags: ['nodejs_compat'],
  d1Databases: ['DB'], r2Buckets: ['CONSENT_VIDEO_BUCKET'],
  bindings: {
    ADMIN_API_KEY: 'local-consent-admin',
    NOSTR_NSEC: nip19.nsecEncode(syntheticAdminKey),
    MANAGEMENT_URL: 'https://relay.test/management',
    FUNNELCAKE_API_URL: 'https://funnelcake.test',
    ZENDESK_SUBDOMAIN: 'consent-local', ZENDESK_EMAIL: 'agent@example.test',
    ZENDESK_API_TOKEN: 'local-only',
    KEYCAST_URL: 'https://keycast.test', KEYCAST_SERVICE_TOKEN: 'local-only',
    CONSENT_ACCESS_TEAM_DOMAIN: 'consent-access.test', CONSENT_ACCESS_AUD: 'consent-local',
    PROTECTED_MINOR_TOMBSTONE_KEY: 'local-consent-tombstone',
    NIP98_PUBLIC_HOST_ALLOWLIST: '', AUTO_HIDE_ENABLED: 'false',
  },
  outboundService: async request => {
    const url = new URL(request.url);
    outbound.push(`${request.method} ${url.hostname}${url.pathname}`);
    if (url.hostname === 'consent-access.test' && url.pathname === '/cdn-cgi/access/certs') {
      return json({ keys: [jwk] });
    }
    if (url.hostname === 'consent-local.zendesk.com') {
      if (request.method !== 'GET') {
        const body = await request.json();
        if (body.ticket?.comment?.body) comments.push(body.ticket.comment);
        return json({ ticket: { id: ticketId }, user: { id: 1 } });
      }
      if (url.pathname.includes('/comments')) return json({ comments });
      return json({ ticket: { id: ticketId, requester_id: 1 }, user: { id: 1 } });
    }
    if (url.hostname === 'keycast.test') {
      return json({ success: true, status: 'active', verified_minor: request.method === 'PUT' });
    }
    if (url.hostname === 'relay.test') return json({ result: true });
    if (url.hostname === 'funnelcake.test') return json({ data: [], pagination: { next_cursor: null } });
    unexpected.push(request.url);
    return json({ error: 'Unexpected outbound request denied' }, 502);
  },
});
await mf.ready;
const DB = await mf.getD1Database('DB');
// Running the status route initializes the production schema without adding data.
// The seed endpoint initializes via a bundled production ensureSchema below.
// Use the same production migration function against the main real D1 binding.
// esbuild's Node bundle permits importing this pure SQL initializer directly.
await build({ entryPoints: [join(backend, 'worker/src/db.ts')], outfile: join(output, 'schema.cjs'), bundle: true, platform: 'node', format: 'cjs' });
await require(join(output, 'schema.cjs')).ensureSchema(DB);
const server = createServer(async (incoming, outgoing) => {
  try {
    const url = `http://${incoming.headers.host}${incoming.url}`;
    let response;
    if (incoming.url.startsWith('/__test/state')) {
      response = json({
        cases: (await DB.prepare('SELECT id,pubkey,state,version FROM age_review_cases').all()).results,
        submissions: (await DB.prepare('SELECT case_id,receipt_id,status,size_bytes FROM age_review_parent_consent_submissions').all()).results,
        comments, outbound, unexpected,
      });
    } else if (incoming.url.startsWith('/__test/token')) {
      const mode = new URL(url).searchParams.get('mode');
      response = json({ token: accessToken(mode === 'expired' ? { exp: 1 } : mode === 'audience' ? { aud: ['wrong'] } : {}) });
    } else {
      const chunks = [];
      for await (const chunk of incoming) chunks.push(chunk);
      const body = Buffer.concat(chunks);
      response = await mf.dispatchFetch(url, {
        method: incoming.method, headers: incoming.headers,
        ...(['GET','HEAD'].includes(incoming.method) ? {} : { body }),
      });
    }
    outgoing.writeHead(response.status, Object.fromEntries(response.headers));
    outgoing.end(Buffer.from(await response.arrayBuffer()));
  } catch (error) {
    outgoing.writeHead(500, { 'content-type': 'application/json' });
    outgoing.end(JSON.stringify({ error: String(error) }));
  }
});
server.listen(Number(process.env.CONSENT_TEST_PORT ?? 48787), '127.0.0.1', () => {
  console.log(`CONSENT_ACCEPTANCE_READY http://127.0.0.1:${server.address().port}`);
});
async function close() {
  server.close(); await mf.dispose(); await rm(output, { recursive: true, force: true });
  process.exit(0);
}
process.on('SIGTERM', close);
process.on('SIGINT', close);
