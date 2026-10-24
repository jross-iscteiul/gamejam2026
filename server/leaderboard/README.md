# Self-hosted leaderboard

Live API: **https://leaderboard-gamejam2026.suricata-lab.com**. Deployed in the homelab; HTTPS health and leaderboard reads were verified on 2026-10-24, including CORS/preflight for itch.io and the configured GitHub Pages origin. The Godot client also registered a temporary run and sent authenticated checkpoints 1–3 successfully; no test score was submitted. The game connection is enabled in `leaderboard.cfg`; export/upload this revision to connect the published game. Only the leaderboard API/database run here; the game remains hosted on itch.io. This folder contains the app and deployment files for future updates.

The app uses Node 24's bundled SQLite and HTTP modules, with no npm dependencies. `/data` stores scores and run records persistently. The container runs as the `node` user. SQLite uses WAL mode and prepared statements. No admin key, shared browser secret, external account, or third-party leaderboard service is needed.

## Deploy using your existing homelab proxy

Build `server/leaderboard/Dockerfile` with `server/leaderboard/` as its build context. Run the resulting image with a persistent volume mounted at `/data`, internal port **8080**, and these environment variables:

```sh
docker build -t gamejam2026-leaderboard server/leaderboard
# Or, from this folder, start just the app service (without the optional Caddy):
docker compose up -d --build leaderboard
```

Attach the app to your proxy's Docker network, or adapt the supplied Compose file to your homelab's networking convention.

| Variable | Value |
|---|---|
| `DATABASE_PATH` | `/data/leaderboard.sqlite` (image default) |
| `ALLOWED_ORIGINS` | Comma-separated **exact game iframe origins**; see `.env.example` |
| `TRUST_PROXY` | `1` only when the API is reachable solely through your trusted reverse proxy |
| `MIN_RUN_MS` | `1000` initially; tune the minimum valid full-run time after playtesting |

Route HTTPS for `leaderboard-gamejam2026.suricata-lab.com` to the container's port 8080. Keep that port internal when trusting proxy headers. Your proxy must replace incoming `X-Forwarded-For` with a trusted client address; the app uses the rightmost address for rate limiting. If you expose the app directly, leave `TRUST_PROXY=0` and terminate HTTPS elsewhere as appropriate.

## Optional standalone Caddy deployment

If the host does not already use ports 80/443, point the domain's A/AAAA records at it, copy `.env.example` to `.env`, then:

```sh
cd server/leaderboard
docker compose up -d --build
curl https://leaderboard-gamejam2026.suricata-lab.com/health
```

The supplied Caddyfile configures automatic HTTPS and forwards to the API. Named volumes keep the database and certificate data across container replacements. If your homelab already has a proxy, use the app container behind that proxy instead of starting a second Caddy on the same ports. Back up the `/data` volume; stop the app for a simple consistent filesystem copy, then restart it. Do not discard the database volume when updating the image.

## Connect the itch.io game

1. Check `/health` returns JSON with `ok: true` over trusted HTTPS.
2. Set `ALLOWED_ORIGINS` to the origin of the **actual exported game's iframe**, which may be an `itch.zone` origin rather than the itch.io store page. The example includes `https://html-classic.itch.zone` and the existing GitHub Pages origin; verify these against your published build. Origins have no trailing path or slash.
3. The game's root `leaderboard.cfg` already has the live URL and `enabled=true`. Export/upload this revision of the game; older exported builds retain their previous configuration. Automated tests explicitly disable or fake networking and do not use the live service.
4. Start **New Game**, complete levels 1–4 and defeat the boss, then choose a public racer name and **Submit My Run**. Chapter Select and Restart Level are practice. The current checkout still lacks the real boss/credits ending, so normal gameplay cannot complete a full run until Package 4 emits `boss_defeated`.

The UI also exposes Refresh in the main-menu and pause-menu Leaderboard pages. Names allow 2–16 ASCII letters, digits, spaces, underscores and hyphens. Names are public nicknames, not authenticated accounts; the server keeps the best time per case-insensitive name and ruleset. There is no ownership guarantee for a nickname.

## Timing and API

Ruleset: `full_run_active_v1`. Lower integer milliseconds are better. Timing starts with level 1 gameplay, pauses with the game, excludes intro/menu/loading time, includes deaths and respawns, and stops on boss defeat. The client includes four split times and a death count. Local personal bests work without the server; online runs must register successfully at New Game.

| Endpoint | Purpose |
|---|---|
| `GET /health` | Health check |
| `GET /v1/leaderboard?ruleset=full_run_active_v1` | Top 10 names/times, ascending, with stable tie ordering |
| `POST /v1/runs` `{ruleset}` | Register a run; returns a random, six-hour `run_token` |
| `POST /v1/checkpoints` `{level: 1..3}` | Record ordered level exits; requires `Authorization: Bearer <run_token>` |
| `POST /v1/scores` `{name, ruleset, time_ms, splits_ms, deaths}` | Submit after all three checkpoints, with the same bearer token |

Tokens are stored hashed, stay in client memory and never appear in leaderboard responses. Identical submission/checkpoint retries are idempotent. A consumed token cannot change its result. Invalid schemas, split totals, rulesets, expired runs and impossible elapsed-time bounds are rejected. Requests are limited per IP (240/minute, new runs 60/hour); CORS restricts browser origins and request bodies are bounded.

This is an **honour-based game-jam leaderboard**, not authoritative anti-cheat: a modified game or scripted client can fabricate checkpoints and times. CORS and run tokens do not prove a genuine playthrough. Strong competitive validation would require server simulation or replay verification. Review suspicious times in your own SQLite database; there is no public administration endpoint. Use a new ruleset/board when timing rules or the game route change materially.

## Local checks

```sh
cd server/leaderboard
node --test server.test.mjs
# Optional local API (use a development database)
node server.mjs
```

Game-side integration and timer/HUD tests live in `tests/game_logic/`. No live domain access is required by tests. Node API tests run in CI.
