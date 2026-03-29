# frozen_string_literal: true

require 'tmpdir'
require 'stringio'

RSpec.describe Umgr::Runner do
  subject(:runner) { described_class.new }

  it 'is instantiable' do
    expect(runner).to be_a(described_class)
  end

  it 'returns ok for #ping' do
    expect(runner.ping).to eq(:ok)
  end

  it 'dispatches not_implemented for remaining placeholder actions' do
    Dir.mktmpdir do |tmp_dir|
      File.write(File.join(tmp_dir, 'users.yml'), "version: 1\nresources: []\n")

      %i[validate].each do |action|
        result = Dir.chdir(tmp_dir) { runner.dispatch(action, config: 'users.yml') }

        expect(result[:action]).to eq(action.to_s)
        expect(result[:status]).to eq('not_implemented')
        expect(result[:ok]).to be(false)
        expect(result[:state_path]).to end_with('/.umgr/state.json')
      end
    end
  end

  it 'imports current users from providers and persists imported state' do
    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      local_runner = described_class.new(state_backend: backend)
      File.write(
        File.join(tmp_dir, 'users.yml'),
        <<~YAML
          version: 1
          resources:
            - provider: echo
              type: user
              name: alice
              attributes:
                team: platform
        YAML
      )

      result = Dir.chdir(tmp_dir) { local_runner.dispatch(:import, config: 'users.yml') }

      expect(result[:ok]).to be(true)
      expect(result[:status]).to eq('imported')
      expect(result[:imported_count]).to eq(1)
      expect(result.fetch(:state).fetch(:resources)).to eq(
        [
          {
            provider: 'echo',
            type: 'user',
            name: 'alice',
            attributes: { team: 'platform' },
            identity: 'echo.user.alice'
          }
        ]
      )
      expect(backend.read).to eq(result.fetch(:state))
    end
  end

  it 'supports end-to-end workflow from init to show' do
    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      local_runner = described_class.new(state_backend: backend)
      File.write(
        File.join(tmp_dir, 'users.yml'),
        <<~YAML
          version: 1
          resources:
            - provider: echo
              type: user
              name: alice
              attributes:
                team: platform
        YAML
      )

      init_result = Dir.chdir(tmp_dir) { local_runner.dispatch(:init) }
      validate_result = Dir.chdir(tmp_dir) { local_runner.dispatch(:validate, config: 'users.yml') }
      plan_result = Dir.chdir(tmp_dir) { local_runner.dispatch(:plan, config: 'users.yml') }
      apply_result = Dir.chdir(tmp_dir) { local_runner.dispatch(:apply, config: 'users.yml') }
      show_result = Dir.chdir(tmp_dir) { local_runner.dispatch(:show) }

      expect(init_result[:status]).to eq('initialized')
      expect(validate_result[:status]).to eq('not_implemented')
      expect(plan_result[:status]).to eq('planned')
      expect(plan_result.dig(:changeset, :summary)).to eq(create: 1, update: 0, delete: 0, no_change: 0)
      expect(apply_result[:status]).to eq('applied')
      expect(show_result[:status]).to eq('ok')
      expect(show_result[:state]).to eq(apply_result[:state])
      expect(backend.read).to eq(show_result[:state])
    end
  end

  it 'applies desired state and persists resulting state' do
    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      backend.write(
        version: 1,
        resources: [{ provider: 'echo', type: 'user', name: 'alice', attributes: { team: 'infra' } }]
      )
      local_runner = described_class.new(state_backend: backend)
      File.write(
        File.join(tmp_dir, 'users.yml'),
        <<~YAML
          version: 1
          resources:
            - provider: echo
              type: user
              name: alice
              attributes:
                team: platform
            - provider: echo
              type: user
              name: carla
        YAML
      )

      result = Dir.chdir(tmp_dir) { local_runner.dispatch(:apply, config: 'users.yml') }

      expect(result[:ok]).to be(true)
      expect(result[:status]).to eq('applied')
      expect(result.fetch(:changeset).fetch(:summary)).to eq(create: 1, update: 1, delete: 0, no_change: 0)
      expect(result.fetch(:apply_results).map { |item| item[:status] }).to eq(%w[applied applied])
      expect(result.fetch(:idempotency)).to eq(
        checked: true,
        stable: true,
        summary: { create: 0, update: 0, delete: 0, no_change: 2 }
      )
      expect(backend.read).to eq(result.fetch(:state))
    end
  end

  it 'keeps existing state unchanged when apply fails' do
    failing_provider = Class.new do
      def validate(resource:)
        { ok: true, resource: resource }
      end

      def current(resource:)
        { ok: true, account: resource }
      end

      def plan(desired:, current:)
        { ok: true, provider: 'failing', status: desired == current ? 'no_change' : 'planned' }
      end

      def apply(changeset:)
        { ok: false, provider: 'failing', error: "cannot apply #{changeset.fetch(:identity)}" }
      end
    end.new

    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      backend.write(
        version: 1,
        resources: [{ provider: 'failing', type: 'user', name: 'alice', attributes: { team: 'infra' } }]
      )
      before_apply_state = backend.read
      registry = Umgr::ProviderRegistry.new
      registry.register('failing', failing_provider)
      local_runner = described_class.new(state_backend: backend, provider_registry: registry)

      File.write(
        File.join(tmp_dir, 'users.yml'),
        <<~YAML
          version: 1
          resources:
            - provider: failing
              type: user
              name: alice
              attributes:
                team: platform
        YAML
      )

      expect do
        Dir.chdir(tmp_dir) { local_runner.dispatch(:apply, config: 'users.yml') }
      end.to raise_error(Umgr::Errors::InternalError, /Provider apply failed/)
      expect(backend.read).to eq(before_apply_state)
    end
  end

  it 'is idempotent when plan is run after apply' do
    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      backend.write(version: 1, resources: [])
      local_runner = described_class.new(state_backend: backend)
      File.write(
        File.join(tmp_dir, 'users.yml'),
        <<~YAML
          version: 1
          resources:
            - provider: echo
              type: user
              name: alice
              attributes:
                team: platform
        YAML
      )

      Dir.chdir(tmp_dir) { local_runner.dispatch(:apply, config: 'users.yml') }
      plan_result = Dir.chdir(tmp_dir) { local_runner.dispatch(:plan, config: 'users.yml') }

      expect(plan_result[:status]).to eq('planned')
      expect(plan_result.fetch(:changeset).fetch(:summary)).to eq(create: 0, update: 0, delete: 0, no_change: 1)
      expect(plan_result.fetch(:drift)).to eq(
        detected: false,
        change_count: 0,
        actions: { create: 0, update: 0, delete: 0 }
      )
    end
  end

  it 'returns a planned changeset for desired vs current state' do
    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      backend.write(
        version: 1,
        resources: [
          { provider: 'echo', type: 'user', name: 'alice', attributes: { team: 'infra' } },
          { provider: 'echo', type: 'user', name: 'bob' }
        ]
      )
      local_runner = described_class.new(state_backend: backend)
      File.write(
        File.join(tmp_dir, 'users.yml'),
        <<~YAML
          version: 1
          resources:
            - provider: echo
              type: user
              name: alice
              attributes:
                team: platform
            - provider: echo
              type: user
              name: carla
        YAML
      )

      result = Dir.chdir(tmp_dir) { local_runner.dispatch(:plan, config: 'users.yml') }
      changes = result.fetch(:changeset).fetch(:changes)

      expect(result[:ok]).to be(true)
      expect(result[:status]).to eq('planned')
      expect(changes.map { |change| [change[:identity], change[:action]] }).to eq(
        [
          ['echo.user.alice', 'update'],
          ['echo.user.bob', 'delete'],
          ['echo.user.carla', 'create']
        ]
      )
      expect(result.fetch(:changeset).fetch(:summary)).to eq(create: 1, update: 1, delete: 1, no_change: 0)
      expect(result.fetch(:drift)).to eq(
        detected: true,
        change_count: 3,
        actions: { create: 1, update: 1, delete: 1 }
      )
    end
  end

  it 'includes github provider-specific plan details in structured plan changes' do
    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      backend.write(
        version: 1,
        resources: [
          { provider: 'github', type: 'user', name: 'alice', org: 'acme', teams: %w[admins platform] }
        ]
      )
      local_runner = described_class.new(state_backend: backend)
      File.write(
        File.join(tmp_dir, 'users.yml'),
        <<~YAML
          version: 1
          resources:
            - provider: github
              type: user
              name: alice
              org: acme
              token: secret
              teams:
                - admins
                - security
        YAML
      )

      result = Dir.chdir(tmp_dir) { local_runner.dispatch(:plan, config: 'users.yml') }
      change = result.fetch(:changeset).fetch(:changes).find { |item| item[:identity] == 'github.user.alice' }

      expect(change[:action]).to eq('update')
      expect(change.fetch(:provider_plan)).to include(
        provider: 'github',
        organization_action: 'keep',
        status: 'planned'
      )
      expect(change.fetch(:provider_plan).fetch(:team_actions)).to eq(
        add: ['security'],
        remove: ['platform'],
        unchanged: ['admins']
      )
      expect(change.fetch(:provider_plan).fetch(:operations)).to eq(
        [
          { type: 'add_team_membership', login: 'alice', team: 'security' },
          { type: 'remove_team_membership', login: 'alice', team: 'platform' }
        ]
      )
    end
  end

  it 'returns not_initialized when show is called without state' do
    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      local_runner = described_class.new(state_backend: backend)

      result = local_runner.dispatch(:show)

      expect(result[:ok]).to be(true)
      expect(result[:status]).to eq('not_initialized')
      expect(result[:state]).to be_nil
      expect(result[:state_path]).to eq(File.join(tmp_dir, '.umgr', 'state.json'))
    end
  end

  it 'returns current state when show is called with initialized state' do
    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      backend.write(version: 1, resources: [{ provider: 'github', type: 'user', name: 'alice' }])
      local_runner = described_class.new(state_backend: backend)

      result = local_runner.dispatch(:show)

      expect(result[:ok]).to be(true)
      expect(result[:status]).to eq('ok')
      expect(result[:state]).to eq(version: 1, resources: [{ provider: 'github', type: 'user', name: 'alice' }])
    end
  end

  it 'initializes state on init' do
    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      local_runner = described_class.new(state_backend: backend)

      result = local_runner.dispatch(:init)

      expect(result[:ok]).to be(true)
      expect(result[:status]).to eq('initialized')
      expect(result[:state]).to eq(version: 1, resources: [])
      expect(File.file?(File.join(tmp_dir, '.umgr', 'state.json'))).to be(true)
      expect(backend.read).to eq(version: 1, resources: [])
    end
  end

  it 'returns already_initialized when state exists' do
    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      backend.write(version: 1, resources: [{ provider: 'github', type: 'user', name: 'alice' }])
      local_runner = described_class.new(state_backend: backend)

      result = local_runner.dispatch(:init)

      expect(result[:ok]).to be(true)
      expect(result[:status]).to eq('already_initialized')
      expect(result[:state]).to eq(version: 1, resources: [{ provider: 'github', type: 'user', name: 'alice' }])
    end
  end

  it 'passes options to dispatched methods' do
    Dir.mktmpdir do |tmp_dir|
      File.write(File.join(tmp_dir, 'users.yml'), "version: 1\nresources: []\n")

      result = Dir.chdir(tmp_dir) { runner.dispatch(:validate, config: 'users.yml') }

      expect(result[:options][:config]).to end_with('/users.yml')
    end
  end

  it 'compiles DSL into validated config' do
    Dir.mktmpdir do |tmp_dir|
      File.write(
        File.join(tmp_dir, 'umgr.rb'),
        <<~RUBY
          umgr do
            version = 1
          end

          resource 'echo.user', 'alice', attributes: { team: 'platform' }
        RUBY
      )

      result = Dir.chdir(tmp_dir) { runner.dispatch(:compile) }

      expect(result[:ok]).to be(true)
      expect(result[:status]).to eq('compiled')
      expect(result[:options][:dsl]).to end_with('/umgr.rb')
      expect(result[:config]).to eq(
        {
          'version' => 1,
          'resources' => [
            {
              'provider' => 'echo',
              'type' => 'user',
              'name' => 'alice',
              'attributes' => { 'team' => 'platform' }
            }
          ]
        }
      )
    end
  end

  it 'auto-discovers config when not explicitly provided' do
    Dir.mktmpdir do |tmp_dir|
      config_path = File.join(tmp_dir, 'umgr.yml')
      File.write(config_path, "version: 1\nresources: []\n")

      result = Dir.chdir(tmp_dir) { runner.dispatch(:validate) }

      expect(result[:options][:config]).to end_with('/umgr.yml')
    end
  end

  it 'reads config from stdin when --config - is used' do
    input = StringIO.new(
      "{\"version\":1,\"resources\":[{\"provider\":\"echo\",\"type\":\"user\",\"name\":\"alice\"}]}\n"
    )
    original_stdin = $stdin
    $stdin = input

    result = runner.dispatch(:validate, config: '-')

    expect(result[:options][:config]).to eq('-')
    identity = result.fetch(:options).fetch(:desired_state).fetch(:resources).first.fetch(:identity)
    expect(identity).to eq('echo.user.alice')
  ensure
    $stdin = original_stdin
  end

  it 'uses explicit config path over auto-discovery candidates' do
    Dir.mktmpdir do |tmp_dir|
      File.write(File.join(tmp_dir, 'umgr.yml'), "version: 1\nresources: []\n")
      explicit_path = File.join(tmp_dir, 'custom.json')
      File.write(explicit_path, "{\"version\":1,\"resources\":[]}\n")

      result = Dir.chdir(tmp_dir) { runner.dispatch(:validate, config: 'custom.json') }

      expect(result[:options][:config]).to end_with('/custom.json')
    end
  end

  it 'raises validation error on auto-discovery ambiguity between DSL and static config' do
    Dir.mktmpdir do |tmp_dir|
      File.write(File.join(tmp_dir, 'umgr.rb'), "umgr do\n  version = 1\nend\n")
      File.write(File.join(tmp_dir, 'umgr.yml'), "version: 1\nresources: []\n")

      expect do
        Dir.chdir(tmp_dir) { runner.dispatch(:validate) }
      end.to raise_error(Umgr::Errors::ValidationError, /Auto-discovery ambiguity/)
    end
  end

  it 'raises validation error when required config is missing' do
    expect { runner.dispatch(:validate) }
      .to raise_error(Umgr::Errors::ValidationError, /config/)
  end

  it 'raises validation error when only DSL source is present' do
    Dir.mktmpdir do |tmp_dir|
      File.write(File.join(tmp_dir, 'umgr.rb'), "umgr do\n  version = 1\nend\n")

      expect do
        Dir.chdir(tmp_dir) { runner.dispatch(:validate) }
      end.to raise_error(Umgr::Errors::ValidationError, /compile first/)
    end
  end

  it 'raises validation error when explicit config is missing' do
    expect { runner.dispatch(:validate, config: 'does-not-exist.yml') }
      .to raise_error(Umgr::Errors::ValidationError, /Config file not found/)
  end

  it 'raises validation error when version type is invalid' do
    Dir.mktmpdir do |tmp_dir|
      File.write(File.join(tmp_dir, 'invalid.yml'), "version: banana\nresources: []\n")

      expect do
        Dir.chdir(tmp_dir) { runner.dispatch(:validate, config: 'invalid.yml') }
      end.to raise_error(Umgr::Errors::ValidationError, /`version` must be a positive integer/)
    end
  end

  it 'raises validation error when top-level required keys are missing' do
    Dir.mktmpdir do |tmp_dir|
      File.write(File.join(tmp_dir, 'invalid.yml'), "resources: []\n")

      expect do
        Dir.chdir(tmp_dir) { runner.dispatch(:validate, config: 'invalid.yml') }
      end.to raise_error(Umgr::Errors::ValidationError, /Missing required key `version`/)
    end
  end

  it 'raises validation error when resource required fields are missing' do
    Dir.mktmpdir do |tmp_dir|
      File.write(File.join(tmp_dir, 'invalid.yml'), "version: 1\nresources:\n  - provider: github\n")

      expect do
        Dir.chdir(tmp_dir) { runner.dispatch(:validate, config: 'invalid.yml') }
      end.to raise_error(Umgr::Errors::ValidationError, /missing required string field `type`/)
    end
  end

  it 'preserves attributes and provider-specific resource fields in desired_state' do
    Dir.mktmpdir do |tmp_dir|
      File.write(
        File.join(tmp_dir, 'users.yml'),
        <<~YAML
          version: 1
          resources:
            - provider: echo
              type: user
              name: alice
              attributes:
                email: alice@example.com
                first_name: Alice
              org: platform
              roles:
                - admin
                - writer
        YAML
      )

      result = Dir.chdir(tmp_dir) { runner.dispatch(:validate, config: 'users.yml') }
      resource = result[:options][:desired_state][:resources].first

      expect(resource[:attributes]).to eq(
        email: 'alice@example.com',
        first_name: 'Alice'
      )
      expect(resource[:org]).to eq('platform')
      expect(resource[:roles]).to eq(%w[admin writer])
    end
  end

  it 'adds canonical identity to desired_state resources' do
    Dir.mktmpdir do |tmp_dir|
      File.write(
        File.join(tmp_dir, 'users.yml'),
        <<~YAML
          version: 1
          resources:
            - provider: echo
              type: user
              name: alice
        YAML
      )

      result = Dir.chdir(tmp_dir) { runner.dispatch(:validate, config: 'users.yml') }
      resource = result.fetch(:options).fetch(:desired_state).fetch(:resources).first

      expect(resource[:identity]).to eq('echo.user.alice')
    end
  end

  it 'raises validation error when provider is unknown in config-backed actions' do
    Dir.mktmpdir do |tmp_dir|
      File.write(
        File.join(tmp_dir, 'users.yml'),
        <<~YAML
          version: 1
          resources:
            - provider: atlassian
              type: user
              name: alice
        YAML
      )

      %i[validate plan apply import].each do |action|
        expect do
          Dir.chdir(tmp_dir) { runner.dispatch(action, config: 'users.yml') }
        end.to raise_error(Umgr::Errors::ValidationError, /Unknown provider\(s\) for #{action}: atlassian/)
      end
    end
  end

  it 'raises validation error for invalid github provider configuration' do
    Dir.mktmpdir do |tmp_dir|
      File.write(
        File.join(tmp_dir, 'users.yml'),
        <<~YAML
          version: 1
          resources:
            - provider: github
              type: user
              name: alice
              token_env: GITHUB_TOKEN
        YAML
      )

      expect do
        Dir.chdir(tmp_dir) { runner.dispatch(:validate, config: 'users.yml') }
      end.to raise_error(Umgr::Errors::ValidationError, /requires non-empty `org`/)
    end
  end

  it 'keeps action methods private' do
    described_class::ACTIONS.each do |action|
      expect(runner).not_to respond_to(action)
    end
  end

  it 'raises for unsupported actions' do
    expect { runner.dispatch(:unknown) }
      .to raise_error(Umgr::Errors::UnknownActionError, /Unknown action/)
  end
end
