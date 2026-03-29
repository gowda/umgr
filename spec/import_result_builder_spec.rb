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
    allow(state_backend).to receive(:write)

    result = described_class.call(state_backend: state_backend, options: options, provider_registry: provider_registry)

    expect(result[:ok]).to be(true)
    expect(result[:status]).to eq('imported')
    expect(result[:imported_count]).to eq(2)
    expect(state_backend).to have_received(:write).with(
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
    allow(state_backend).to receive(:write)

    expect do
      described_class.call(state_backend: state_backend, options: options, provider_registry: provider_registry)
    end.to raise_error(Umgr::Errors::InternalError, /denied/)
    expect(state_backend).not_to have_received(:write)
  end

  it 'uses account fallback shape when provider returns account attributes hash' do
    allow(provider_registry).to receive(:fetch).with('echo').and_return(provider)
    allow(provider).to receive(:current).and_return(
      ok: true,
      account: { team: 'security', title: 'engineer' }
    )
    allow(state_backend).to receive(:write)

    result = described_class.call(state_backend: state_backend, options: options, provider_registry: provider_registry)
    resource = result.fetch(:state).fetch(:resources).first

    expect(resource).to eq(
      provider: 'echo',
      type: 'user',
      name: 'alice',
      attributes: { team: 'security', title: 'engineer' },
      identity: 'echo.user.alice'
    )
  end

  it 'raises internal error when provider current returns no recognized resource keys' do
    allow(provider_registry).to receive(:fetch).with('echo').and_return(provider)
    allow(provider).to receive(:current).and_return(ok: true, ignored: 'value')
    allow(state_backend).to receive(:write)

    expect do
      described_class.call(state_backend: state_backend, options: options, provider_registry: provider_registry)
    end.to raise_error(Umgr::Errors::InternalError, /missing imported resources/)
    expect(state_backend).not_to have_received(:write)
  end

  it 'raises internal error when account fallback is not a hash' do
    allow(provider_registry).to receive(:fetch).with('echo').and_return(provider)
    allow(provider).to receive(:current).and_return(ok: true, account: 'some_string')
    allow(state_backend).to receive(:write)

    expect do
      described_class.call(state_backend: state_backend, options: options, provider_registry: provider_registry)
    end.to raise_error(Umgr::Errors::InternalError, /missing imported resources/)
    expect(state_backend).not_to have_received(:write)
  end
end
