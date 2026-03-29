# TODO

- [x] Phase 0: README Bootstrap
  <details>
  <summary>Tasks (1)</summary>

  - [x] Task 0.1: Create brief README.md with motivation, interfaces, config/state model, and non-exhaustive provider examples

  </details>
- [x] Phase 1: Foundation + Shared Runtime
  <details>
  <summary>Tasks (6)</summary>

  - [x] Task 1.1: Scaffold gem, executable, Thor CLI wiring, RSpec/Aruba setup, RuboCop + rubocop-performance config
  - [x] Task 1.2: Implement shared CLI->Runner command dispatch for init, validate, plan, apply, show, and import
  - [x] Task 1.3: Implement unified errors and CLI exit-code mapping
  - [x] Task 1.4: Add Dependabot config for bundler and github-actions with ecosystem-specific grouping
  - [x] Task 1.5: Add explicit permissions block to checks workflow
  - [x] Task 1.6: Add coverage tracking in checks workflow

  </details>
- [x] Phase 2: Config + Validation
  <details>
  <summary>Tasks (3)</summary>

  - [x] Task 2.1: Support YAML/JSON config auto-discovery and --config override
  - [x] Task 2.2: Enforce core schema validation (provider/type/name and top-level shape)
  - [x] Task 2.3: Preserve hybrid payload fields (attributes + provider-specific options)

  </details>
- [x] Phase 3: State Backend + Visibility
  <details>
  <summary>Tasks (3)</summary>

  - [x] Task 3.1: Implement local state backend (.umgr/state.json) with atomic writes
  - [x] Task 3.2: Implement init command/API for state initialization
  - [x] Task 3.3: Implement show command/API for state inspection

  </details>
- [x] Phase 4: Provider Framework + Echo Provider
  <details>
  <summary>Tasks (3)</summary>

  - [x] Task 4.1: Define provider interface contract (validate/current/plan/apply) and registry
  - [x] Task 4.2: Implement unknown-provider handling in validation/runtime flows
  - [x] Task 4.3: Implement built-in echo test provider that echoes fake user account attributes

  </details>
- [x] Phase 5: Provider Authoring Documentation
  <details>
  <summary>Tasks (2)</summary>

  - [x] Task 5.1: Add detailed provider/plugin authoring guide in separate markdown file after first provider implementation
  - [x] Task 5.2: Update README.md to point to provider authoring guide

  </details>
- [x] Phase 6: Planning Engine
  <details>
  <summary>Tasks (4)</summary>

  - [x] Task 6.1: Implement canonical resource identity (provider.type.name)
  - [x] Task 6.2: Implement desired-vs-current diff and change-set generation
  - [x] Task 6.3: Implement plan outputs (human default + --json)
  - [x] Task 6.4: Implement explicit drift detection reporting in plan output and API results

  </details>
- [x] Phase 7: First Concrete Provider (GitHub)
  <details>
  <summary>Tasks (4)</summary>

  - [x] Task 7.1: Implement GitHub provider scaffold and registration
  - [x] Task 7.2: Implement GitHub import/current state retrieval
  - [x] Task 7.3: Implement GitHub drift planning for org + team membership
  - [x] Task 7.4: Implement GitHub apply execution for membership reconciliation

  </details>
- [x] Phase 8: Apply Engine
  <details>
  <summary>Tasks (4)</summary>

  - [x] Task 8.1: Implement apply execution and state persistence
  - [x] Task 8.2: Implement idempotency checks (apply then plan yields no changes)
  - [x] Task 8.3: Implement failure safety to prevent state corruption on apply errors
  - [x] Task 8.4: Implement import command/API to fetch current users from providers/plugins into managed state

  </details>

- [x] Phase 9: Hardening + Docs Consistency
  <details>
  <summary>Tasks (5)</summary>

  - [x] Task 9.1: Add end-to-end workflow coverage (init -> validate -> plan -> apply -> show)
  - [x] Task 9.1a: Re-enable `rubocop-rspec` cops and align test suite with enforced guidelines
  - [x] Task 9.2: Run README/provider-doc consistency pass and fix mismatches
  - [x] Task 9.3: Final stabilization with all checks green
  - [x] Task 9.4: Add static GitHub Pages website for umgr (single-page, precise/exhaustive, no bloat)

  </details>

- [x] Phase 10: Release + Distribution
  <details>
  <summary>Tasks (5)</summary>

  - [x] Prerequisite: Task 9.4 static website is completed before publishing work
  - [x] Task 10.1: Add private publish workflow for GitHub Packages triggered by GitHub Release publish event
  - [x] Task 10.2: Enforce progressive SemVer validation in release workflow before publish
  - [x] Task 10.3: Document private installation and Gemfile usage for GitHub Packages in README.md
  - [x] Task 10.4: Add public RubyGems publish readiness plan using OIDC trusted publishing (no long-lived API key secrets)

  </details>

- [ ] Phase 11: Post-Release DSL Config Generator
  - [ ] Task 11.1: Add Ruby DSL compiler that generates authoritative YAML/JSON config output (DSL is not runtime source)
    - [ ] Define deterministic compile command (`umgr compile`) and output path policy
    - [ ] Define DSL/config precedence policy for runtime commands (`validate/plan/apply/import`)
    - [ ] Fail fast on auto-discovery ambiguity when both `umgr.rb` and `umgr.{yml,yaml,json}` exist
    - [ ] Define explicit stdin contract: support `--config -` for piped compiled config
    - [ ] Add pipeline example: `umgr compile | umgr plan --config -`
    - [ ] Add pipeline example: `umgr compile | umgr apply --config -`
    - [ ] Ensure compiled output strictly conforms to existing config schema validation
    - [ ] CLI verification (Aruba)
    - [ ] Library verification (RSpec)
    - [ ] Pre-commit checks passed (rubocop + rspec + aruba)
    - [ ] Commit created
  - [ ] Task 11.2: Add branching/looping-friendly DSL constructs for account lifecycles and provider matrices
    - [ ] Support conditional inclusion and iteration helpers without changing final config schema
    - [ ] Add deterministic ordering guarantees to avoid noisy diffs in generated config
    - [ ] CLI verification (Aruba)
    - [ ] Library verification (RSpec)
    - [ ] Pre-commit checks passed (rubocop + rspec + aruba)
    - [ ] Commit created
  - [ ] Task 11.3: Add DSL safety rails and docs
    - [ ] Restrict side effects in DSL evaluation context and document recommended usage patterns
    - [ ] Document precedence matrix (explicit `--config` vs `--config -` vs auto-discovery)
    - [ ] Document ambiguity error messaging and resolution steps (`--config` or compile pipeline)
    - [ ] Clarify runtime commands never execute DSL directly; DSL must be compiled
    - [ ] Add examples showing DSL -> compiled YAML/JSON workflow
    - [ ] Update README with explicit guidance: compile output is canonical input for `validate/plan/apply/import`
    - [ ] CLI verification (Aruba)
    - [ ] Library verification (RSpec)
    - [ ] Pre-commit checks passed (rubocop + rspec + aruba)
    - [ ] Commit created
