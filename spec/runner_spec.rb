# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Umgr::Runner do
  subject(:runner) { described_class.new }
  let(:provider_class) do
    Class.new do
      def validate(resource:); end
      def current(resource:); end
      def plan(desired:, current:); end
      def apply(changeset:); end
    end
  end

  it 'is instantiable' do
    expect(runner).to be_a(described_class)
  end

  it 'returns ok for #ping' do
    expect(runner.ping).to eq(:ok)
  end

  it 'dispatches not_implemented for remaining placeholder actions' do
    Dir.mktmpdir do |tmp_dir|
      File.write(File.join(tmp_dir, 'users.yml'), "version: 1\nresources: []\n")

      %i[validate plan apply import].each do |action|
        result = Dir.chdir(tmp_dir) { runner.dispatch(action, config: 'users.yml') }

        expect(result[:action]).to eq(action.to_s)
        expect(result[:status]).to eq('not_implemented')
        expect(result[:ok]).to eq(false)
        expect(result[:state_path]).to end_with('/.umgr/state.json')
      end
    end
  end

  it 'returns not_initialized when show is called without state' do
    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      local_runner = described_class.new(state_backend: backend)

      result = local_runner.dispatch(:show)

      expect(result[:ok]).to eq(true)
      expect(result[:status]).to eq('not_initialized')
      expect(result[:state]).to eq(nil)
      expect(result[:state_path]).to eq(File.join(tmp_dir, '.umgr', 'state.json'))
    end
  end

  it 'returns current state when show is called with initialized state' do
    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      backend.write(version: 1, resources: [{ provider: 'github', type: 'user', name: 'alice' }])
      local_runner = described_class.new(state_backend: backend)

      result = local_runner.dispatch(:show)

      expect(result[:ok]).to eq(true)
      expect(result[:status]).to eq('ok')
      expect(result[:state]).to eq(version: 1, resources: [{ provider: 'github', type: 'user', name: 'alice' }])
    end
  end

  it 'initializes state on init' do
    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      local_runner = described_class.new(state_backend: backend)

      result = local_runner.dispatch(:init)

      expect(result[:ok]).to eq(true)
      expect(result[:status]).to eq('initialized')
      expect(result[:state]).to eq(version: 1, resources: [])
      expect(File.file?(File.join(tmp_dir, '.umgr', 'state.json'))).to eq(true)
      expect(backend.read).to eq(version: 1, resources: [])
    end
  end

  it 'returns already_initialized when state exists' do
    Dir.mktmpdir do |tmp_dir|
      backend = Umgr::StateBackend.new(root_dir: tmp_dir)
      backend.write(version: 1, resources: [{ provider: 'github', type: 'user', name: 'alice' }])
      local_runner = described_class.new(state_backend: backend)

      result = local_runner.dispatch(:init)

      expect(result[:ok]).to eq(true)
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

  it 'auto-discovers config when not explicitly provided' do
    Dir.mktmpdir do |tmp_dir|
      config_path = File.join(tmp_dir, 'umgr.yml')
      File.write(config_path, "version: 1\nresources: []\n")

      result = Dir.chdir(tmp_dir) { runner.dispatch(:validate) }

      expect(result[:options][:config]).to end_with('/umgr.yml')
    end
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

  it 'raises validation error when required config is missing' do
    expect { runner.dispatch(:validate) }
      .to raise_error(Umgr::Errors::ValidationError, /config/)
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
      registry = Umgr::ProviderRegistry.new
      registry.register(:github, provider_class.new)
      File.write(
        File.join(tmp_dir, 'users.yml'),
        <<~YAML
          version: 1
          resources:
            - provider: github
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

      local_runner = described_class.new(provider_registry: registry)
      result = Dir.chdir(tmp_dir) { local_runner.dispatch(:validate, config: 'users.yml') }
      resource = result[:options][:desired_state][:resources].first

      expect(resource[:attributes]).to eq(
        email: 'alice@example.com',
        first_name: 'Alice'
      )
      expect(resource[:org]).to eq('platform')
      expect(resource[:roles]).to eq(%w[admin writer])
    end
  end

  it 'raises validation error when provider is unknown in config-backed actions' do
    Dir.mktmpdir do |tmp_dir|
      File.write(
        File.join(tmp_dir, 'users.yml'),
        <<~YAML
          version: 1
          resources:
            - provider: github
              type: user
              name: alice
        YAML
      )

      %i[validate plan apply import].each do |action|
        expect do
          Dir.chdir(tmp_dir) { runner.dispatch(action, config: 'users.yml') }
        end.to raise_error(Umgr::Errors::ValidationError, /Unknown provider\(s\) for #{action}: github/)
      end
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
