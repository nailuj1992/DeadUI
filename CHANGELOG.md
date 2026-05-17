# Changelog

All notable changes to **Dead UI** are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-17

### Added
- Initial public release.
- Death banner with animated presets (`pulse`, `flash`, `bob`, `shake`, `grow`, `static`).
- Test Mode checkbox to preview the banner while alive.
- Sound picker merging user-registered sounds with `LibSharedMedia-3.0`.
- Custom Sounds sub-block inside the Sound section for adding/removing user entries from `Interface\Sounds\*.ogg`.
- Font picker via `LibSharedMedia-3.0` with font preview in the dropdown.
- Position slider for vertical offset.
- Slash commands: `/dead`, `/dead config`, `/dead test`, `/dead off`, `/dead reset`.
- "Reset configuration" header button replacing the default Blizzard defaults button on the DeadUI category.
- GitHub Actions release pipeline (`release.yml`, `.pkgmeta`) for automated packaging and CurseForge deployment on tag push.
