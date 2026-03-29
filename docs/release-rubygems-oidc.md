# RubyGems OIDC Release Readiness

This document defines the readiness steps to publish `umgr` to public
RubyGems using OIDC trusted publishing (no long-lived API key).

## Goals

- Keep private pre-release flow on GitHub Packages.
- Promote stable releases to public RubyGems only after trusted publishing is
  configured.
- Avoid static RubyGems API key secrets.

## Workflow Gate

`publish-rubygems` workflow (`.github/workflows/publish-rubygems.yml`) is
release-triggered and includes:

- `permissions: id-token: write`
- stable-tag guard (`vX.Y.Z` expected for public release)
- readiness gate that intentionally fails until trusted publishing is configured

This makes release intent explicit while preventing accidental public publishes.

## Trusted Publishing Prerequisites

Before enabling public publish:

1. In RubyGems, configure Trusted Publishing for this GitHub repository.
2. Bind the trusted publisher to the workflow path:
   `.github/workflows/publish-rubygems.yml`.
3. Ensure release tags and environments match RubyGems policy expectations.

After prerequisites are complete, replace the readiness gate step with the
official RubyGems trusted-publishing publish step.

## Promotion Path

1. Ship pre-release versions (`vX.Y.Z.pre.N`) to private GitHub Packages.
2. Validate in downstream/private environments.
3. Cut stable version (`vX.Y.Z`) and publish to RubyGems through the OIDC
   trusted workflow.

This keeps early validation private and makes public release explicit.
