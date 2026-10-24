import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createLeaderboardServer, RULESET } from './server.mjs';

const origin = 'https://html-classic.itch.zone';
async function fixture(t, overrides = {}) {
  let now = Date.now();
  const app = createLeaderboardServer({ databasePath: ':memory:', allowedOrigins: [origin], now: () => now, ...overrides });
  await new Promise(resolve => app.server.listen(0, '127.0.0.1', resolve));
  t.after(() => app.close());
  const base = `http://127.0.0.1:${app.server.address().port}`;
  async function request(path, body, token, headers = {}) {
    const response = await fetch(base + path, {
      method: body === undefined ? 'GET' : 'POST',
      headers: { Origin: origin, ...(body === undefined ? {} : { 'Content-Type': 'application/json' }), ...(token ? { Authorization: 'Bearer ' + token } : {}), ...headers },
      body: body === undefined ? undefined : JSON.stringify(body)
    });
    return { status: response.status, data: await response.json(), headers: response.headers };
  }
  async function run() {
    const started = await request('/v1/runs', { ruleset: RULESET });
    assert.equal(started.status, 201);
    const token = started.data.run_token;
    for (const level of [1, 2, 3]) assert.equal((await request('/v1/checkpoints', { level }, token)).status, 200);
    now += 10000;
    return token;
  }
  return { ...app, base, request, run, advance: ms => { now += ms; } };
}
const score = (name, time = 4000) => ({ name, time_ms: time, ruleset: RULESET, deaths: 0, splits_ms: [1000, 1000, 1000, time - 3000] });

test('health, CORS preflight and exact origin allowlist', async t => {
  const f = await fixture(t);
  const health = await f.request('/health');
  assert.equal(health.status, 200);
  assert.equal(health.headers.get('access-control-allow-origin'), origin);
  const preflight = await fetch(f.base + '/v1/scores', { method: 'OPTIONS', headers: { Origin: origin } });
  assert.equal(preflight.status, 204);
  assert.match(preflight.headers.get('access-control-allow-headers'), /Authorization/);
  assert.equal((await f.request('/health', undefined, null, { Origin: 'https://unrelated.example' })).status, 403);
});
test('ordered checkpoints and an authenticated run are required', async t => {
  const f = await fixture(t);
  assert.equal((await f.request('/v1/scores', score('Racer'))).status, 401);
  const token = (await f.request('/v1/runs', { ruleset: RULESET })).data.run_token;
  assert.equal((await f.request('/v1/checkpoints', { level: 2 }, token)).status, 409);
  assert.equal((await f.request('/v1/scores', score('Racer'), token)).status, 409);
  assert.equal((await f.request('/v1/checkpoints', { level: 1 }, token)).status, 200);
  assert.equal((await f.request('/v1/checkpoints', { level: 1 }, token)).status, 200);
});
test('ascending times, personal bests, ties and idempotent retries', async t => {
  const f = await fixture(t);
  const token = await f.run();
  assert.equal((await f.request('/v1/scores', score('Alice', 5000), token)).status, 200);
  assert.equal((await f.request('/v1/scores', score('Alice', 5000), token)).status, 200);
  assert.equal((await f.request('/v1/scores', score('Alice', 4000), token)).status, 409);
  assert.equal((await f.request('/v1/scores', score('ALICE', 6000), await f.run())).status, 200);
  await f.request('/v1/scores', score('Bob', 4000), await f.run());
  let rows = (await f.request('/v1/leaderboard?ruleset=' + RULESET)).data.items;
  assert.deepEqual(rows.map(r => [r.rank, r.name, r.time_ms]), [[1, 'Bob', 4000], [2, 'Alice', 5000]]);
  await f.request('/v1/scores', score('Alice', 4000), await f.run());
  rows = (await f.request('/v1/leaderboard?ruleset=' + RULESET)).data.items;
  assert.equal(rows.length, 2);
  assert.equal(rows[0].name, 'Bob');
});
test('reject malformed names, impossible timings, bad rulesets and mismatched splits', async t => {
  const f = await fixture(t);
  const token = await f.run();
  for (const invalid of [
    { ...score('Racer'), name: '<script>' }, { ...score('Racer'), time_ms: -1 },
    { ...score('Racer'), time_ms: 4000.5 }, { ...score('Racer'), splits_ms: [1, 2] },
    { ...score('Racer'), splits_ms: [1, 2, 3, 4] }, { ...score('Racer'), deaths: -1 },
    { ...score('Racer'), ruleset: 'practice' }, { ...score('Racer'), name: 'a'.repeat(17) }
  ]) assert.equal((await f.request('/v1/scores', invalid, token)).status, 400);
  assert.equal((await f.request('/v1/scores', score('Racer', 100000), token)).status, 409);
  assert.equal((await f.request('/v1/leaderboard?ruleset=old')).status, 400);
});
test('expired tokens and request/run rate limits', async t => {
  const f = await fixture(t, { runsPerHour: 1, requestsPerMinute: 20 });
  const token = await f.run();
  assert.equal((await f.request('/v1/runs', { ruleset: RULESET })).status, 429);
  f.advance(7 * 60 * 60 * 1000);
  assert.equal((await f.request('/v1/scores', score('Racer'), token)).status, 401);
  for (let i = 0; i < 19; i++) await f.request('/health');
  assert.equal((await f.request('/health')).status, 429);
});
test('bounds request bodies and rejects invalid JSON/content types', async t => {
  const f = await fixture(t);
  assert.equal((await f.request('/v1/runs', { padding: 'a'.repeat(9000) })).status, 413);
  const invalid = await fetch(f.base + '/v1/runs', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: '{' });
  assert.equal(invalid.status, 400);
  const wrongType = await fetch(f.base + '/v1/runs', { method: 'POST', body: '{}' });
  assert.equal(wrongType.status, 415);
});
test('SQLite scores survive a server restart and internal run credentials are not public', async t => {
  const directory = mkdtempSync(join(tmpdir(), 'gamejam-leaderboard-'));
  const path = join(directory, 'scores.sqlite');
  const f = await fixture(t, { databasePath: path });
  await f.request('/v1/scores', score('Saved'), await f.run());
  await f.close();
  const second = await fixture(t, { databasePath: path });
  t.after(() => {
    assert.ok(directory.startsWith(join(tmpdir(), 'gamejam-leaderboard-')));
    rmSync(directory, { recursive: true, force: true });
  });
  const rows = (await second.request('/v1/leaderboard?ruleset=' + RULESET)).data.items;
  assert.equal(rows[0].name, 'Saved');
  assert.deepEqual(Object.keys(rows[0]).sort(), ['name', 'rank', 'time_ms']);
});
