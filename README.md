# umgr

`umgr` is a Ruby tool for managing user account state across platforms using a
Terraform-like desired-state workflow.

You declare desired state in a YAML or JSON configuration file, and `umgr`
compares it with tracked current state to generate and apply changes.

## Motivation

Organizations often need to keep user accounts consistent across many systems.
`umgr` provides one interface to define account intent and reconcile drift.

Examples of platforms include Google Workspace, Atlassian, GitHub, Slack, AWS,
Azure, and Sentry. This list is illustrative, not exhaustive.

## Interfaces

`umgr` exposes two interfaces:

- CLI for operators (built with Thor)
- Ruby gem API for embedding in larger applications

## Provider/Plugin Model

Each platform integration is implemented as a provider/plugin.

- Providers implement platform-specific sync logic with SDKs or REST APIs.
- Providers can expose additional provider-specific options on top of the core
  interface.
- The first built-in test provider is `echo`, which returns a fake user account
  by echoing configured attributes.

Detailed provider authoring documentation will be added after the first provider
implementation.

## Configuration and State

- Configuration formats: YAML and JSON
- Model: desired state (config) + current state reference (tool-managed state)
- Core identity convention: `provider.type.name`

## CLI Example

```bash
umgr validate --config examples/users.yml
umgr plan --config examples/users.yml
umgr apply --config examples/users.yml
```

## Ruby API Example

```ruby
require "umgr"

runner = Umgr::Runner.new
result = runner.plan(config_path: "examples/users.yml", format: :json)

puts result[:ok]
puts result[:changes]
```
