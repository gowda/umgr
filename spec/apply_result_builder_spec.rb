# frozen_string_literal: true

RSpec.describe Umgr::ApplyResultBuilder do
  let(:state_backend) { instance_double(Umgr::StateBackend, path: '/tmp/.umgr/state.json') }
  let(:provider_registry) { instance_double(Umgr::ProviderRegistry) }
  let(:provider) { instance_double(Umgr::Providers::EchoProvider) }
  let(:desired_state) do
    {
      version: 1,
      resources: [
        { provider: 'echo', type: 'user', name: 'alice', identity: 'echo.user.alice', attributes: { team: 'platform' } }
      ]
    }
  end
  let(:options) { { config: '/tmp/users.yml', desired_state: desired_state } }

  before do
    allow(state_backend).to receive(:read).and_return(
      version: 1,
      resources: [
        { provider: 'echo', type: 'user', name: 'alice', identity: 'echo.user.alice', attributes: { team: 'infra' } }
      ]
    )
    allow(provider_registry).to receive(:fetch).with('echo').and_return(provider)
    allow(provider).to receive(:plan).and_return(ok: true, provider: 'echo', status: 'planned')
    allow(provider).to receive(:apply).and_return(ok: true, provider: 'echo', status: 'applied')
  end

  it 'applies changes and persists desired state' do
    expect(state_backend).to receive(:write).with(
      {
        version: 1,
        resources: desired_state[:resources]
      }
    )

    result = described_class.call(state_backend: state_backend, options: options, provider_registry: provider_registry)

    expect(result[:ok]).to eq(true)
    expect(result[:status]).to eq('applied')
    expect(result.fetch(:state)).to eq(version: 1, resources: desired_state[:resources])
    expect(result.fetch(:apply_results).first.fetch(:status)).to eq('applied')
  end

  it 'does not persist state if provider apply returns ok: false' do
    allow(provider).to receive(:apply).and_return(ok: false, error: 'boom')

    expect(state_backend).not_to receive(:write)
    expect do
      described_class.call(state_backend: state_backend, options: options, provider_registry: provider_registry)
    end.to raise_error(Umgr::Errors::InternalError, /Provider apply failed/)
  end

  it 'skips no_change operations without invoking provider apply' do
    allow(provider).to receive(:plan).and_return(ok: true, provider: 'echo', status: 'no_change')
    allow(state_backend).to receive(:read).and_return(version: 1, resources: desired_state[:resources])
    allow(state_backend).to receive(:write)

    result = described_class.call(state_backend: state_backend, options: options, provider_registry: provider_registry)

    expect(provider).not_to have_received(:apply)
    expect(result.fetch(:apply_results).first).to include(action: 'no_change', status: 'skipped')
  end
end
