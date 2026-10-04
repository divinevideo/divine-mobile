// Exercises the real Worker through Docker's published port. Only synthetic
// identities are used; no production host or credentials are accepted.
import assert from 'node:assert/strict';
import { createHash, randomBytes } from 'node:crypto';
import http from 'node:http';
import { schnorr } from '@noble/secp256k1';

const transport = new URL(process.env.NAME_SERVER_TRANSPORT ?? 'http://host.docker.internal:43005');
assert.equal(transport.protocol, 'http:');
assert.ok(['localhost', '127.0.0.1', 'host.docker.internal'].includes(transport.hostname));
const hash = (value) => createHash('sha256').update(value).digest();
const key = hash('Divine local name-server smoke identity');
const otherKey = hash('Divine local name-server smoke second identity');
const pubkey = Buffer.from(schnorr.getPublicKey(key)).toString('hex');

async function request(origin, path, { body, signer = key, signedOrigin = origin } = {}) {
  const headers = { Host: new URL(origin).host };
  const method = body === undefined ? 'GET' : 'POST';
  let payload;
  if (body !== undefined) {
    payload = JSON.stringify(body);
    const event = {
      pubkey: Buffer.from(schnorr.getPublicKey(signer)).toString('hex'),
      created_at: Math.floor(Date.now() / 1000), kind: 27235,
      tags: [['u', signedOrigin + path], ['method', method], ['payload', hash(payload).toString('hex')]],
      content: '',
    };
    event.id = hash(JSON.stringify([0, event.pubkey, event.created_at, event.kind, event.tags, event.content])).toString('hex');
    event.sig = Buffer.from(await schnorr.signAsync(Buffer.from(event.id, 'hex'), signer)).toString('hex');
    headers.Authorization = `Nostr ${Buffer.from(JSON.stringify(event)).toString('base64')}`;
    headers['Content-Type'] = 'application/json';
  }
  return new Promise((resolve, reject) => {
    const req = http.request(new URL(path, transport), { method, headers, timeout: 10000 }, (response) => {
      let text = '';
      response.on('data', (chunk) => { text += chunk; });
      response.on('end', () => {
        try { resolve({ status: response.statusCode, data: JSON.parse(text) }); }
        catch (error) { reject(error); }
      });
    });
    req.on('error', reject);
    req.on('timeout', () => req.destroy(new Error('Name server request timed out')));
    req.end(payload);
  });
}

const desktop = 'http://localhost:43005';
if (process.argv.includes('--verify-seed')) {
  const owner = Buffer.from(schnorr.getPublicKey(otherKey)).toString('hex');
  const result = await request(desktop, `/api/username/by-pubkey/${owner}`);
  assert.equal(result.status, 200);
  assert.equal(result.data.name, 'localtaken');
  console.log('Synthetic fixture survived restart and repeat migrations.');
} else if (process.argv.includes('--seed')) {
  const result = await request(desktop, '/api/username/claim', { body: { name: 'localtaken' }, signer: otherKey });
  assert.equal(result.status, 200);
  assert.equal(result.data.ok, true);
  console.log('Seeded localtaken with a synthetic owner. Reserved fixture: admin.');
} else {
  for (const origin of [desktop, 'http://10.0.2.2:43005']) {
    const name = `local${randomBytes(5).toString('hex')}`;
    const available = await request(origin, `/api/username/check/${name}`);
    assert.equal(available.status, 200);
    assert.equal(available.data.available, true);
    const reserved = await request(origin, '/api/username/check/admin');
    assert.equal(reserved.data.code, 'reserved');
    const mismatch = await request(origin, '/api/username/claim', {
      body: { name }, signedOrigin: 'http://localhost:8787',
    });
    assert.equal(mismatch.status, 401);
    const claim = await request(origin, '/api/username/claim', { body: { name } });
    assert.equal(claim.status, 200);
    assert.equal(claim.data.ok, true);
    assert.equal(claim.data.pubkey, pubkey);
    const taken = await request(origin, `/api/username/check/${name}`);
    assert.equal(taken.data.code, 'taken');
    const conflict = await request(origin, '/api/username/claim', { body: { name }, signer: otherKey });
    assert.equal(conflict.status, 409);
    const lookup = await request(origin, `/api/username/by-pubkey/${pubkey}`);
    assert.equal(lookup.status, 200);
    assert.equal(lookup.data.name, name);
    const attempt = `local-${randomBytes(12).toString('hex')}`;
    const prepare = await request(origin, '/api/username/release/prepare', { body: { name, attempt_id: attempt } });
    assert.equal(prepare.status, 200);
    const rollback = await request(origin, '/api/username/release/rollback', { body: { name, attempt_id: attempt } });
    assert.equal(rollback.status, 200);
    const restored = await request(origin, `/api/username/by-pubkey/${pubkey}`);
    assert.equal(restored.data.name, name);
    console.log(`Passed check, signed claim, conflict, lookup and release rollback via ${origin}`);
  }
}
