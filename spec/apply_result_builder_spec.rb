# frozen_string_literal: true

RSpec.describe Umgr::ApplyResultBuilder do
  let(:state_backend) { instance_double(Umgr::StateBackend, path: '/tmp/.umgr/state.json') }
  let(:provider_registry) { instance_double(Umgr::ProviderRegistry) }
  let(:provider) { instance_double(Umgr::Providers::EchoProvider) }
  let(:persisted_state) do
    {
      version: 1,
      resources: [
        { provider: 'echo', type: 'user', name: 'alice', identity: 'echo.user.alice', attributes: { team: 'infra' } }
      ]
    }
  end
  let(:desired_state) do
    {
      version: 1,
      resources: [
        { provider: 'echo', type: 'user', name: 'alice', identity: 'echo.user.alice', attributes: { team: 'platform' } }
      ]
    }
  end

  before do
    stored_state = persisted_state
    allow(state_backend).to receive(:read) { stored_state }
    allow(state_backend).to receive(:write) { |new_state| stored_state = new_state }
    allow(provider_registry).to receive(:fetch).with('echo').and_return(provider)
    allow(provider).to receive(:plan).and_return(ok: true, provider: 'echo', status: 'planned')
    allow(provider).to receive(:apply).and_return(ok: true, provider: 'echo', status: 'applied')
  end

  it 'applies changes and persists desired state' do
    result = described_class.call(
      state_backend: state_backend,
      options: { config: '/tmp/users.yml', desired_state: desired_state },
      provider_registry: provider_registry
    )

    expect(result[:ok]).to eq(true)
    expect(result[:status]).to eq('applied')
    expect(result.fetch(:state)).to eq(version: 1, resources: desired_state[:resources])
    expect(result.fetch(:apply_results).first.fetch(:status)).to eq('applied')
    expect(result.fetch(:idempotency)).to eq(
      checked: true,
      stable: true,
      summary: { create: 0, update: 0, delete: 0, no_change: 1 }
    )
    expect(state_backend.read).to eq(version: 1, resources: desired_state[:resources])
  end

  it 'does not persist state if provider apply returns ok: false' do
    allow(provider).to receive(:apply).and_return(ok: false, error: 'boom')

    expect(state_backend).not_to receive(:write)
    expect do
      described_class.call(
        state_backend: state_backend,
        options: { config: '/tmp/users.yml', desired_state: desired_state },
        provider_registry: provider_registry
      )
    end.to raise_error(Umgr::Errors::InternalError, /Provider apply failed/)
  end

  it 'skips no_change operations without invoking provider apply' do
    allow(provider).to receive(:plan).and_return(ok: true, provider: 'echo', status: 'no_change')
    allow(state_backend).to receive(:read).and_return(version: 1, resources: desired_state[:resources])
    allow(state_backend).to receive(:write)

    result = described_class.call(
      state_backend: state_backend,
      options: { config: '/tmp/users.yml', desired_state: desired_state },
      provider_registry: provider_registry
    )

    expect(provider).not_to have_received(:apply)
    expect(result.fetch(:apply_results).first).to include(action: 'no_change', status: 'skipped')
    expect(result.fetch(:idempotency).fetch(:stable)).to eq(true)
  end

  it 'raises internal error when post-apply plan still includes changes' do
    allow(state_backend).to receive(:read).and_return(persisted_state)
    allow(state_backend).to receive(:write)

    expect do
      described_class.call(
        state_backend: state_backend,
        options: { config: '/tmp/users.yml', desired_state: desired_state },
        provider_registry: provider_registry
      )
    end.to raise_error(Umgr::Errors::InternalError, /Apply is not idempotent/)
  end

  it 'raises internal error when change does not include provider information' do
    change = { identity: 'missing.provider', action: 'update', desired: nil, current: nil }

    expect do
      described_class.send(:apply_change, change, provider_registry)
    end.to raise_error(Umgr::Errors::InternalError, /Missing provider/)
  end
end
