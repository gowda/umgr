# frozen_string_literal: true

RSpec.describe Umgr::ImportResultBuilder do
  let(:state_backend) { instance_double(Umgr::StateBackend, path: '/tmp/.umgr/state.json') }
  let(:provider_registry) { instance_double(Umgr::ProviderRegistry) }
  let(:provider) { instance_double(Umgr::Providers::EchoProvider) }
  let(:desired_state) do
    {
      version: 1,
      resources: [
        { provider: 'echo', type: 'user', name: 'alice', attributes: { team: 'platform' } }
      ]
    }
  end
  let(:options) { { config: '/tmp/users.yml', desired_state: desired_state } }

  it 'imports provider current state and persists deduplicated resources' do
    allow(provider_registry).to receive(:fetch).with('echo').and_return(provider)
    allow(provider).to receive(:current).and_return(
      ok: true,
      imported_accounts: [
        { provider: 'echo', type: 'user', name: 'alice', attributes: { team: 'infra' } },
        { provider: 'echo', type: 'user', name: 'alice', attributes: { team: 'platform' } },
        { provider: 'echo', type: 'user', name: 'bob' }
      ]
    )
    expect(state_backend).to receive(:write).with(
      {
        version: 1,
        resources: [
          {
            provider: 'echo',
            type: 'user',
            name: 'alice',
            attributes: { team: 'platform' },
            identity: 'echo.user.alice'
          },
          {
            provider: 'echo',
            type: 'user',
            name: 'bob',
            identity: 'echo.user.bob'
          }
        ]
      }
    )

    result = described_class.call(state_backend: state_backend, options: options, provider_registry: provider_registry)

    expect(result[:ok]).to eq(true)
    expect(result[:status]).to eq('imported')
    expect(result[:imported_count]).to eq(2)
  end

  it 'uses returned resource payload when provider returns a single resource' do
    allow(provider_registry).to receive(:fetch).with('echo').and_return(provider)
    allow(provider).to receive(:current).and_return(
      ok: true,
      resource: { provider: 'echo', type: 'user', name: 'carla', attributes: { title: 'manager' } }
    )
    allow(state_backend).to receive(:write)

    result = described_class.call(state_backend: state_backend, options: options, provider_registry: provider_registry)
    imported = result.fetch(:state).fetch(:resources)

    expect(imported).to eq(
      [{ provider: 'echo', type: 'user', name: 'carla', attributes: { title: 'manager' }, identity: 'echo.user.carla' }]
    )
  end

  it 'raises internal error when provider current returns ok: false' do
    allow(provider_registry).to receive(:fetch).with('echo').and_return(provider)
    allow(provider).to receive(:current).and_return(ok: false, error: 'denied')
    expect(state_backend).not_to receive(:write)

    expect do
      described_class.call(state_backend: state_backend, options: options, provider_registry: provider_registry)
    end.to raise_error(Umgr::Errors::InternalError, /denied/)
  end
end
