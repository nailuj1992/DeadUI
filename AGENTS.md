# AGENTS.md — Dead UI

Guidance for AI coding agents working in this repository.

## Project

World of Warcraft addon that plays a sound and shows an animated "YOU ARE DEAD!" banner when your character dies. Animation, text, font, colour, position and sound are all configurable.

- **Author / maintainer:** Nailuj1992
- **CurseForge:** https://www.curseforge.com/wow/addons/dead-ui (project ID `1545594`)
- **Language:** Lua 5.1 (WoW UI environment), plus TOC and XML

### Supported clients

One TOC serves every client through a comma-separated `## Interface` list.

| Client | Version | Interface |
|---|---|---|
| Retail (Midnight) | 12.1.5 | `120105` |
| MoP Classic | 5.5.4 | `50504` |
| TBC Classic Anniversary | 2.5.6 | `20506` |
| Classic Era | 1.15.9 | `11509` |
| WoW Forever (beta) | 1.60.1 | `16001` |

WoW Forever reports a `1.x` build and expansion level 0, so it can't be detected by version alone. Use `WOW_PROJECT_ID == WOW_PROJECT_CAMELOT` or an interface number between 16000 and 19999.

## Layout

| File | Purpose |
|---|---|
| `DeadUI.toc` | Metadata, interface list, load order |
| `embeds.xml` | Loads the embedded libraries |
| `main.lua` | Defaults, SavedVariables (`DeadUIDB`), banner frame, animations, death events |
| `options.lua` | Settings panel, custom sound management, slash commands (`/deadui`, `/dead`, `/dui`) |
| `Libs/` | Third-party libraries. **Not tracked in git.** |
| `.pkgmeta` | BigWigs packager config (externals, ignore list, changelog) |
| `.github/workflows/release.yml` | Builds and uploads to CurseForge when a tag is pushed |

Libraries: LibStub, CallbackHandler-1.0, LibSharedMedia-3.0, LibChangelog, UTF8 (from `.pkgmeta` externals) and LibEQOL (installed by the workflow).

`main.lua` loads before `options.lua` and exposes its API on the global `DeadUI` table (`NS`). Code in `options.lua` must only use what `main.lua` publishes there.

## Guidelines

- **Cross-client APIs:** every API must exist on all five clients, or be guarded. Use the existing pattern: `local X = C_Namespace and C_Namespace.X or X`.
- **No new globals.** The only intended globals are `DeadUI`, `DeadUIBanner`, `DeadUIDB`, `OpenDeadUISettings` (used by `AddonCompartmentFunc`) and the slash-command entries.
- **Saved variables:**
  - Add new keys to `DEFAULTS` in `main.lua`. Missing keys are filled in automatically.
  - Bumping `DEFAULTS.version` **overwrites every user setting** with the defaults. Only bump it when that is really intended, and call it out in the changelog.
- **Animations:** add new ones to the `ANIMATIONS` table as `fn(self, t)`. The dropdown picks them up automatically.
- **Custom sounds** live in `Interface\Sounds\*.ogg`. Normalise names with `NS.NormalizeSoundPath`.
- **Settings** go through `LibEQOLSettingsMode-1.0`. `options.lua` must keep its early `return` when the library is missing.
- **Line endings:** `.lua` files use CRLF. Keep them that way.
- **Style:** 4-space indentation, `local` everything, match the surrounding code.

### Releases

- Bump `## Version` in the TOC and add a `CHANGELOG.md` entry together, using [Keep a Changelog](https://keepachangelog.com/en/1.1.0/) format.
- When a client patch ships, update the `## Interface` list and drop numbers for patches that are no longer live.
- Commit messages follow Conventional Commits (`feat:`, `fix:`, `docs:` …).

## Restrictions

- **Never push git tags.** Any tag push triggers `release.yml` and publishes to CurseForge. Releasing is the maintainer's decision.
- **Never push to `master` directly.** Work on a branch and open a pull request.
- **Never commit `Libs/`.** It is git-ignored and filled at build time by the packager. Don't edit library code to fix addon bugs; fix it in the addon. (`Libs/Libs/` is a stray local duplicate: ignore it.)
- **Don't change `.github/workflows/` or `.pkgmeta`** unless asked. Never print, log or commit secrets (`CURSE_API_TOKEN`).
- **Don't touch the user's WoW installation** (`World of Warcraft\_*_\Interface\AddOns`, `WTF`/SavedVariables) unless explicitly asked. Back files up before overwriting them.
- **Changes can't be run here.** No WoW client or Lua runtime is available. Say clearly that in-game testing is still needed; don't claim a change "works".
- **Avoid taint.** Don't modify Blizzard secure frames, and don't call protected functions in combat. Hook with `hooksecurefunc`, not by replacing Blizzard functions.
