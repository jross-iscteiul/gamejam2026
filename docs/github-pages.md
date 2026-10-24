# GitHub Pages web build

The experiment lives on `ci/github-pages`, based on the latest `origin/main`. The workflow tests and exports on pushes to `main` and this experiment branch, pull requests targeting `main`, and manual runs. Branch/PR builds attach a downloadable `web-game` artifact; only `main` deploys the public Pages site.

## Enable hosting

1. In the GitHub repository, open **Settings → Pages**.
2. Set **Build and deployment → Source** to **GitHub Actions**.
3. Merge the workflow branch into `main`. A successful workflow then publishes the game.

The expected URL is **https://jross-iscteiul.github.io/gamejam2026/**. Until Pages is enabled and a `main` deployment succeeds, that URL is not a published build. GitHub's `github-pages` environment may require approval depending on the repository's protection settings. No personal access token or custom secret is required; deployment uses the workflow's `GITHUB_TOKEN` and Pages permissions.

## What CI does

- Installs **Godot 4.7.2 standard** and its matching web release template from official Godot release assets. The installation is cached between builds.
- Imports the project so a clean checkout has its generated assets and script-class cache.
- Runs Package 3 tests, player movement, level flow, and moving-platform tests. Nonzero exit codes, printed `FAIL` results and script errors fail the build; each scene has a timeout.
- Exports the `Web` preset to `build/web/index.html` with **Thread Support off**, compatible with ordinary static HTTPS hosting.
- Uploads a `web-game` artifact on every build and deploys to Pages only from `main`.

The existing movement-gate suite is not a CI gate yet: its `L1 tunnel pit4 / jump+dash` check already fails on the original checkout. See `tests/game_logic/README.md`. Gameplay and other people's level/player files are unchanged by this hosting branch.

## Local export

Install the **Godot 4.7.2 web export template** through **Editor → Manage Export Templates**. Then, from the project folder:

```powershell
godot --headless --path . --editor --quit
New-Item -ItemType Directory -Force build/web
godot --headless --path . --export-release Web build/web/index.html
```

Serve **all files** in `build/web/` through a local HTTP server and open `http://localhost:<port>/`; opening `index.html` directly from disk will not load the game. Godot's Run in Browser option is another way to preview the export. The same exported files can be zipped for itch.io. Exported files are ignored by Git and never need to be committed.

`export_presets.cfg` excludes tests, the level generator and the build directory. It includes the font license and existing asset-license files. The menu, intro, character, levels, display settings and input map are unchanged.

References: [Godot web export](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html), [GitHub Pages custom workflows](https://docs.github.com/en/pages/getting-started-with-github-pages/using-custom-workflows-with-github-pages).
