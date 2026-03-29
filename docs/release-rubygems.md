# RubyGems OIDC Publishing

This document describes the active public RubyGems publishing flow for `umgr`
using OIDC trusted publishing (no long-lived API key).

## Goals

- Keep private pre-release flow on GitHub Packages.
- Publish stable releases to RubyGems via GitHub Releases.
- Avoid static RubyGems API key secrets.

## Active Workflow

`publish-rubygems` workflow (`.github/workflows/publish-rubygems.yml`) is
release-triggered and includes:

- `permissions: id-token: write`
- stable-tag guard (`vX.Y.Z` expected for public release)
- `rubygems/release-gem@v1` publish step

This makes release intent explicit while preventing accidental public publishes
from prerelease tags.

## Trusted Publisher Identity

RubyGems trusted publisher is configured against:

- repository: `gowda/umgr`
- workflow: `.github/workflows/publish-rubygems.yml`
- environment: `release`
- gem: `umgr`

## Promotion Path

1. Ship pre-release versions (`vX.Y.Z.pre.N`) to private GitHub Packages.
2. Validate in downstream/private environments.
3. Cut stable version (`vX.Y.Z`) and publish to RubyGems through the OIDC
   trusted workflow.

This keeps early validation private and makes public release explicit.

## Operational Notes

- Stable tags only:
  - `vX.Y.Z` publishes to RubyGems.
  - `vX.Y.Z.pre.N` is blocked by the stable-tag guard.
- Publish trigger:
  - GitHub Release event: `release.published`.
- Current public package:
  - `https://rubygems.org/gems/umgr`
