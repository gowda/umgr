# umgr

[![checks](https://github.com/gowda/umgr/actions/workflows/checks.yml/badge.svg)](https://github.com/gowda/umgr/actions/workflows/checks.yml)
[![CodeQL Advanced](https://github.com/gowda/umgr/actions/workflows/codeql.yml/badge.svg)](https://github.com/gowda/umgr/actions/workflows/codeql.yml)

`umgr` is a declarative account lifecycle tool for managing user account state
across platforms with a desired-state workflow.

You declare desired state in a YAML or JSON configuration file, and `umgr`
compares it with tracked current state to detect drift, import current users,
and generate/apply changes.

## Motivation

Organizations often need to keep user accounts consistent across many systems.
`umgr` provides one interface to define account intent and reconcile drift.

Examples of platforms include Google Workspace, Atlassian, GitHub, Slack, AWS,
Azure, and Sentry. This list is illustrative, not exhaustive.

## Interfaces

`umgr` exposes two interfaces:

- CLI for operators (built with Thor)
- Ruby gem API for embedding in larger applications

## Core Capabilities

- Drift detection between desired state and platform/user reality.
- Import of current users from providers/plugins as a baseline state.
- Declarative plan/apply workflow for account lifecycle changes.

## Provider/Plugin Model

Each platform integration is implemented as a provider/plugin.

- Providers implement platform-specific sync logic with SDKs or REST APIs.
- Providers can expose additional provider-specific options on top of the core
  interface.
- The first built-in test provider is `echo`, which returns a fake user account
  by echoing configured attributes.

Provider authoring guide:
[`docs/provider-authoring.md`](docs/provider-authoring.md)

Website:
- Site entrypoint: [`docs/index.html`](docs/index.html)
- Local preview/edit guide: [`docs/website.md`](docs/website.md)

## Configuration and State

- Configuration formats: YAML and JSON
- Model: desired state (config) + current state reference (tool-managed state)
- Core identity convention: `provider.type.name`

## CLI Example

```bash
umgr init
umgr validate --config examples/users.yml
umgr plan --config examples/users.yml
umgr apply --config examples/users.yml
umgr show
```

## Ruby API Example

```ruby
require "umgr"

runner = Umgr::Runner.new
result = runner.dispatch(:plan, config: "examples/users.yml")

puts result[:ok]
puts result.dig(:changeset, :summary)
```

## Private Installation (GitHub Packages)

`umgr` pre-releases are published to GitHub Packages (`rubygems`).

1. Create a GitHub token with:
- `read:packages`
- `repo` (required when the package repository is private)

2. Configure RubyGems credentials:

```bash
mkdir -p ~/.gem
cat > ~/.gem/credentials <<'EOF'
---
:github: Bearer <YOUR_GITHUB_TOKEN>
EOF
chmod 0600 ~/.gem/credentials
```

3. Install directly:

```bash
gem install umgr \
  --source "https://rubygems.pkg.github.com/gowda" \
  --key github
```

### Gemfile Usage (Private Package)

```ruby
source "https://rubygems.org"
source "https://rubygems.pkg.github.com/gowda" do
  gem "umgr"
end
```

Configure Bundler authentication for GitHub Packages:

```bash
bundle config set --global rubygems.pkg.github.com "<GITHUB_USERNAME>:<YOUR_GITHUB_TOKEN>"
```

## Public RubyGems Release Path (OIDC)

Public RubyGems publishing is gated behind OIDC trusted publishing readiness.

- Workflow: `.github/workflows/publish-rubygems.yml`
- Readiness + promotion doc: [`docs/release-rubygems-oidc.md`](docs/release-rubygems-oidc.md)
