# Provider Authoring Guide

This guide explains how to write custom `umgr` providers/plugins.

A provider is the platform adapter that knows how to validate desired account
resources, read current account state, compute drift/change intent, and apply
changes using SDKs or REST APIs.

## Provider Responsibilities

A provider must implement four methods:

- `validate(resource:)`
- `current(resource:)`
- `plan(desired:, current:)`
- `apply(changeset:)`

These methods are defined in [`Umgr::Provider`](../lib/umgr/provider.rb). The
base class raises `Umgr::Errors::AbstractMethodError` when a method is not
implemented.

Validation failure contract for `validate(resource:)`:

- Preferred: raise `Umgr::Errors::ValidationError` with a clear message.
- Also supported: return a hash with `ok: false` (or `"ok" => false`), which
  `umgr` promotes to `Umgr::Errors::ValidationError`.

`current(resource:)` return contract (used by `import`):

- Recommended: return `{ ok: true, imported_accounts: [resource_hash, ...] }`.
- Also supported:
  - `{ ok: true, resource: resource_hash }`
  - `{ ok: true, account: account_hash, resource: resource_hash }` where
    `account` must be a hash and is mapped into `attributes`.
- Return `{ ok: false, error: "..." }` (or string-key equivalent) to surface
  provider fetch/import failures.

## Contract Enforcement

Registration is validated by [`Umgr::ProviderContract`](../lib/umgr/provider_contract.rb):

- Provider objects must respond to all required methods.
- Methods must be concrete implementations (not inherited unchanged from
  `Umgr::Provider`).
- Invalid providers raise `Umgr::Errors::ProviderContractError`.

## Registry and Naming

Providers are managed by [`Umgr::ProviderRegistry`](../lib/umgr/provider_registry.rb).

- Register with `register(name, provider_instance)`.
- `name` is normalized to a symbol (for example, `"echo"` -> `:echo`).
- Empty provider names raise `Umgr::Errors::ProviderContractError`.

`umgr` includes one built-in test provider:

- `echo` -> [`Umgr::Providers::EchoProvider`](../lib/umgr/providers/echo_provider.rb)

## Resource Shape and Identity

Current schema validation enforces these required resource keys:

- `provider`
- `type`
- `name`

Canonical identity convention is `provider.type.name`.

Providers can use both:

- core resource fields
- provider-specific fields such as `attributes` and custom option keys

Configuration is read from YAML/JSON, validated, then deep-symbolized before
provider usage. In provider code, access keys as symbols.

## Runtime Flow

For `validate`, `plan`, `apply`, and `import` actions:

1. Runner resolves config path (explicit `--config` or auto-discovery).
2. Config is schema-validated.
3. Unknown providers are rejected early (`UnknownProviderGuard`).
4. Action execution uses provider(s) from the registry.

For import specifically, `Runner#import` persists imported resources into
managed state and returns `{ status: "imported", imported_count: N }`.

## Minimal Provider Example

```ruby
# lib/umgr/providers/acme_provider.rb
# frozen_string_literal: true

module Umgr
  module Providers
    class AcmeProvider < Provider
      def validate(resource:)
        # provider-specific desired-state checks
        { ok: true, provider: 'acme', resource: resource }
      end

      def current(resource:)
        # fetch current account from Acme API
        account = { email: resource.dig(:attributes, :email) }
        { ok: true, provider: 'acme', account: account, resource: resource }
      end

      def plan(desired:, current:)
        status = desired == current ? 'no_change' : 'update'
        { ok: true, provider: 'acme', status: status, desired: desired, current: current }
      end

      def apply(changeset:)
        # execute API call(s)
        { ok: true, provider: 'acme', status: 'applied', changeset: changeset }
      end
    end
  end
end
```

## Registering a Custom Provider

```ruby
require 'umgr'
require 'umgr/providers/acme_provider'

registry = Umgr::ProviderRegistry.new
registry.register(:acme, Umgr::Providers::AcmeProvider.new)

runner = Umgr::Runner.new(provider_registry: registry)
result = runner.dispatch(:validate, config: 'users.yml')
```

## Error Behavior

Use `umgr` error types where possible:

- `Umgr::Errors::ValidationError` for invalid config/resource input
- `Umgr::Errors::ProviderContractError` for provider contract issues
- `Umgr::Errors::InternalError` for unexpected runtime failures

CLI maps `Umgr::Errors::Error` subclasses to exit codes.

## Testing Guidance

Provider work should include both library and CLI coverage.

- Library: RSpec unit specs for each provider method and branch behavior.
- CLI: Aruba-driven command tests for user-facing behavior and exit codes.

Recommended local validation before commit:

```bash
bundle exec rubocop
bundle exec rspec --exclude-pattern "spec/cli/**/*_spec.rb"
bundle exec rspec spec/cli
```

## Echo Provider as Reference

Use the echo provider and its specs as the baseline template:

- Implementation: [`lib/umgr/providers/echo_provider.rb`](../lib/umgr/providers/echo_provider.rb)
- Specs: [`spec/providers/echo_provider_spec.rb`](../spec/providers/echo_provider_spec.rb)
