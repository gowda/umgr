# DSL Compile Guide

`umgr.rb` is a compile-time source only. Runtime commands never execute DSL.

Use `umgr compile` to produce canonical YAML/JSON config, then pass the
compiled output to runtime commands.

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

## DSL Safety Rails

DSL evaluation runs in a restricted context with allowlisted methods only:

- `umgr`
- `version`
- `resource`
- `resources`
- `if_enabled`
- `for_each`
- `provider_matrix`

Unknown methods raise `Umgr::Errors::ValidationError`.

## Schema Guarantee

Compiled output is validated with the same schema checks used by runtime config
loading:

- top-level keys (`version`, `resources`)
- required resource fields (`provider`, `type`, `name`)
- resource/provider validation pipeline
