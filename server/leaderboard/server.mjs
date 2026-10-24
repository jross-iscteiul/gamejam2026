import { createServer } from 'node:http';
import { createHash, randomBytes } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const RULESET = 'full_run_active_v1';
const SIX_HOURS = 6 * 60 * 60 * 1000;
const hash = value => createHash('sha256').update(value).digest('hex');
const integer = value => Number.isSafeInteger(value);
const failure = (status, message) => Object.assign(new Error(message), { status });

export function createLeaderboardServer(options = {}) {
  const databasePath = options.databasePath ?? process.env.DATABASE_PATH ?? './data/leaderboard.sqlite';
  if (databasePath !== ':memory:') mkdirSync(dirname(resolve(databasePath)), { recursive: true });
  const db = new DatabaseSync(databasePath);
  db.exec(`PRAGMA journal_mode=WAL; PRAGMA busy_timeout=5000;
    CREATE TABLE IF NOT EXISTS runs (
      token_hash TEXT PRIMARY KEY, created_at INTEGER NOT NULL, expires_at INTEGER NOT NULL,
      next_level INTEGER NOT NULL DEFAULT 1, result TEXT);
    CREATE TABLE IF NOT EXISTS scores (
      name_key TEXT NOT NULL, name TEXT NOT NULL, ruleset TEXT NOT NULL,
      time_ms INTEGER NOT NULL CHECK(time_ms > 0), splits TEXT NOT NULL,
      deaths INTEGER NOT NULL CHECK(deaths >= 0), created_at INTEGER NOT NULL,
      PRIMARY KEY(name_key, ruleset));
    CREATE INDEX IF NOT EXISTS score_order ON scores(ruleset, time_ms, created_at, name_key);`);
  const now = options.now ?? Date.now;
  const minimum = Number(options.minRunMs ?? process.env.MIN_RUN_MS ?? 1000);
  if (!integer(minimum) || minimum < 1 || minimum > SIX_HOURS) throw Error('Invalid MIN_RUN_MS');
  const origins = new Set(options.allowedOrigins ?? (process.env.ALLOWED_ORIGINS ?? '').split(',').map(s => s.trim()).filter(Boolean));
  const trustProxy = options.trustProxy ?? process.env.TRUST_PROXY === '1';
  const limits = new Map();
  const requestsPerMinute = options.requestsPerMinute ?? 240;
  const runsPerHour = options.runsPerHour ?? 60;
  const cleanup = setInterval(() => {
    for (const [key, value] of limits) if (value.expires <= now()) limits.delete(key);
    db.prepare('DELETE FROM runs WHERE expires_at < ?').run(now());
  }, 60_000).unref();

  function limit(key, maximum, duration) {
    const value = limits.get(key);
    if (!value || value.expires <= now()) limits.set(key, { count: 1, expires: now() + duration });
    else if (++value.count > maximum) throw failure(429, 'Too many requests. Try again later.');
  }
  function readBody(req) {
    if (!(req.headers['content-type'] ?? '').toLowerCase().startsWith('application/json')) throw failure(415, 'Expected JSON');
    return new Promise((resolve, reject) => {
      let size = 0;
      const chunks = [];
      req.on('data', chunk => {
        size += chunk.length;
        if (size > 8192) reject(failure(413, 'Request too large'));
        else chunks.push(chunk);
      });
      req.on('error', reject);
      req.on('end', () => {
        if (size > 8192) return;
        let body;
        try { body = JSON.parse(Buffer.concat(chunks).toString('utf8')); }
        catch { reject(failure(400, 'Invalid JSON')); return; }
        if (!body || typeof body !== 'object' || Array.isArray(body)) reject(failure(400, 'Expected an object'));
        else resolve(body);
      });
    });
  }
  function authenticate(req) {
    const token = /^Bearer ([a-f0-9]{64})$/.exec(req.headers.authorization ?? '')?.[1];
    const run = token && db.prepare('SELECT * FROM runs WHERE token_hash = ?').get(hash(token));
    if (!run || run.expires_at <= now()) throw failure(401, 'Run expired or unknown');
    return run;
  }
  function top() {
    return db.prepare('SELECT name, time_ms FROM scores WHERE ruleset = ? ORDER BY time_ms, created_at, name_key LIMIT 10')
      .all(RULESET).map((row, index) => ({ rank: index + 1, ...row }));
  }
  const server = createServer(async (req, res) => {
    const reply = (status, body) => {
      res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', 'Cache-Control': 'no-store', 'X-Content-Type-Options': 'nosniff' });
      res.end(JSON.stringify(body));
    };
    try {
      const origin = req.headers.origin;
      if (origin && !origins.has(origin)) throw failure(403, 'Origin not allowed');
      if (origin) { res.setHeader('Access-Control-Allow-Origin', origin); res.setHeader('Vary', 'Origin'); }
      if (req.method === 'OPTIONS') {
        res.writeHead(204, { 'Access-Control-Allow-Methods': 'GET, POST, OPTIONS', 'Access-Control-Allow-Headers': 'Content-Type, Authorization', 'Access-Control-Max-Age': '600' });
        res.end(); return;
      }
      const forwarded = req.headers['x-forwarded-for'];
      const ip = trustProxy && typeof forwarded === 'string' ? forwarded.split(',').at(-1).trim() : req.socket.remoteAddress;
      limit(hash(String(ip)), requestsPerMinute, 60_000);
      const url = new URL(req.url, 'http://localhost');
      if (req.method === 'GET' && url.pathname === '/health') { reply(200, { ok: true, ruleset: RULESET }); return; }
      if (req.method === 'GET' && url.pathname === '/v1/leaderboard') {
        if (url.searchParams.get('ruleset') !== RULESET) throw failure(400, 'Unknown ruleset');
        reply(200, { ruleset: RULESET, items: top() }); return;
      }
      if (req.method !== 'POST' || !['/v1/runs', '/v1/checkpoints', '/v1/scores'].includes(url.pathname)) throw failure(404, 'Not found');
      const body = await readBody(req);
      if (url.pathname === '/v1/runs') {
        if (body.ruleset !== RULESET) throw failure(400, 'Unknown ruleset');
        limit('runs:' + hash(String(ip)), runsPerHour, 3_600_000);
        const token = randomBytes(32).toString('hex');
        db.prepare('INSERT INTO runs(token_hash, created_at, expires_at) VALUES (?, ?, ?)').run(hash(token), now(), now() + SIX_HOURS);
        reply(201, { run_token: token, expires_in_seconds: SIX_HOURS / 1000 }); return;
      }
      const run = authenticate(req);
      if (url.pathname === '/v1/checkpoints') {
        if (!integer(body.level) || body.level < 1 || body.level > 3) throw failure(400, 'Invalid level');
        if (run.result || body.level > run.next_level) throw failure(409, 'Checkpoint out of order');
        if (body.level === run.next_level) db.prepare('UPDATE runs SET next_level = next_level + 1 WHERE token_hash = ?').run(run.token_hash);
        reply(200, { ok: true }); return; // Repeated checkpoints are safe to retry.
      }
      const name = typeof body.name === 'string' ? body.name.trim() : '';
      if (!/^[A-Za-z0-9 _-]{2,16}$/.test(name) || body.ruleset !== RULESET || !integer(body.time_ms) || body.time_ms < minimum || body.time_ms > SIX_HOURS
          || !integer(body.deaths) || body.deaths < 0 || body.deaths > 100_000
          || !Array.isArray(body.splits_ms) || body.splits_ms.length !== 4 || body.splits_ms.some(n => !integer(n) || n < 0)
          || body.splits_ms.reduce((a, b) => a + b, 0) !== body.time_ms) throw failure(400, 'Invalid score');
      if (run.next_level !== 4 || body.time_ms > now() - run.created_at + 5000) throw failure(409, 'Run is incomplete or timing is invalid');
      const result = JSON.stringify({ name, time_ms: body.time_ms, splits_ms: body.splits_ms, deaths: body.deaths });
      if (run.result && run.result !== result) throw failure(409, 'Run already submitted');
      db.exec('BEGIN IMMEDIATE');
      try {
        if (!run.result) {
          db.prepare(`INSERT INTO scores(name_key,name,ruleset,time_ms,splits,deaths,created_at) VALUES (?,?,?,?,?,?,?)
            ON CONFLICT(name_key,ruleset) DO UPDATE SET name=excluded.name,time_ms=excluded.time_ms,splits=excluded.splits,deaths=excluded.deaths,created_at=excluded.created_at
            WHERE excluded.time_ms < scores.time_ms`).run(name.toLowerCase(), name, RULESET, body.time_ms, JSON.stringify(body.splits_ms), body.deaths, now());
          db.prepare('UPDATE runs SET result = ? WHERE token_hash = ?').run(result, run.token_hash);
        }
        db.exec('COMMIT');
      } catch (error) { db.exec('ROLLBACK'); throw error; }
      reply(200, { accepted: true, time_ms: body.time_ms });
    } catch (error) {
      if (!res.headersSent && !res.destroyed) reply(error.status ?? 500, { error: error.status ? error.message : 'Internal server error' });
    }
  });
  server.requestTimeout = 15_000;
  server.headersTimeout = 10_000;
  server.maxConnections = 256;
  server.maxHeadersCount = 64;
  let closing;
  return { server, db, close() {
    return closing ??= (async () => { clearInterval(cleanup); await new Promise(resolve => server.close(resolve)); db.close(); })();
  } };
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  const app = createLeaderboardServer();
  app.server.listen(Number(process.env.PORT ?? 8080), process.env.HOST ?? '0.0.0.0', () => console.log('Leaderboard API listening'));
  for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => app.close().then(() => process.exit(0)));
}
