# DSL Compile Guide

`umgr.rb` is a compile-time source only. Runtime commands never execute DSL.

Use `umgr compile` to produce canonical YAML/JSON config, then pass the
compiled output to runtime commands.

## Assignment-Only DSL

`umgr` now uses assignment-only DSL configuration:

- Top-level `umgr` block is required.
- `version` must be assigned inside `umgr` (for example, `version = 1`).
- `resource` must be declared at top-level.
- Resource definition uses only: `resource "provider.type", "name"`.

## Exhaustive Configuration Examples

### `umgr.rb`

```ruby
umgr do
  version = 1
end

resource "echo.user", "alice", attributes: { location: "us" } do
  team = "platform"
  role = "admin"
end

resource "github.user", "bob" do
  org = "acme"
  teams = ["platform", "security"]
end
```

### `umgr.yml` (same content can be saved as `umgr.yaml`)

```yaml
version: 1
resources:
  - provider: echo
    type: user
    name: alice
    attributes:
      location: us
      role: admin
      team: platform
  - provider: github
    type: user
    name: bob
    attributes:
      org: acme
      teams:
        - platform
        - security
```

### `umgr.json`

```json
{
  "version": 1,
  "resources": [
    {
      "provider": "echo",
      "type": "user",
      "name": "alice",
      "attributes": {
        "location": "us",
        "role": "admin",
        "team": "platform"
      }
    },
    {
      "provider": "github",
      "type": "user",
      "name": "bob",
      "attributes": {
        "org": "acme",
        "teams": [
          "platform",
          "security"
        ]
      }
    }
  ]
}
```

## Compile First

```bash
umgr compile > umgr.yml
umgr validate --config umgr.yml
umgr plan --config umgr.yml
umgr apply --config umgr.yml
umgr import --config umgr.yml
```

Pipeline mode is supported through stdin:

```bash
umgr compile | umgr plan --config -
umgr compile | umgr apply --config -
```

## Precedence Matrix

Runtime commands covered: `validate`, `plan`, `apply`, `import`.

1. `--config <path>`: uses the explicit file path.
2. `--config -`: reads config from stdin.
3. No `--config`: auto-discovers `umgr.yml`, then `umgr.yaml`, then `umgr.json`.

## Ambiguity and Resolution

If no `--config` is provided and both `umgr.rb` and any static config file are
present, `umgr` fails fast with an ambiguity error.

Resolution options:

1. Use `--config <path>` to choose one static config file.
2. Use compile pipeline mode:
   - `umgr compile | umgr <command> --config -`

If only `umgr.rb` exists (and no static config is auto-discovered), runtime
commands fail with a compile-first error and include the pipeline hint.

## Migration Notes

### Old syntax to remove

```ruby
umgr do
  version 1
end

resource provider: "echo", type: "user", name: "alice"
```

### New syntax

```ruby
umgr do
  version = 1
end

resource "echo.user", "alice"
```

## Error Examples

- Missing top-level `umgr` block:
  - `Top-level 'umgr' block is required`
- Legacy keyword resource syntax:
  - `Legacy resource syntax is not supported ... Use: resource 'provider.type', 'name'`
- Invalid resource identifier:
  - `Resource identifier must be in 'provider.type' format`
- Method-style version:
  - `Unsupported DSL method 'version'`
- Unsupported `umgr` assignment:
  - `Unsupported 'umgr' assignment(s): ...`
- Ambiguous auto-discovery (`umgr.rb` + static config):
  - fails fast and asks you to use `--config` or compile pipeline mode.

## DSL Safety Rails

DSL evaluation runs in a restricted context with allowlisted methods only:

- `umgr`
- `resource`
- `resources`
- `if_enabled`
- `for_each`
- `provider_matrix`

`version` is not a DSL method; set it only via assignment inside `umgr`.

Unknown methods raise `Umgr::Errors::ValidationError`.

## Schema Guarantee

Compiled output is validated with the same schema checks used by runtime config
loading:

- top-level keys (`version`, `resources`)
- required resource fields (`provider`, `type`, `name`)
- resource/provider validation pipeline
