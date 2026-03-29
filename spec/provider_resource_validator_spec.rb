# frozen_string_literal: true

RSpec.describe Umgr::ProviderResourceValidator do
  it 'delegates validation to provider for each desired resource' do
    provider = instance_double(Umgr::Providers::EchoProvider)
    registry = instance_double(Umgr::ProviderRegistry)
    desired_state = {
      resources: [
        { provider: 'echo', type: 'user', name: 'alice' },
        { provider: 'echo', type: 'user', name: 'bob' }
      ]
    }

    allow(registry).to receive(:fetch).with('echo').and_return(provider)
    allow(provider).to receive(:validate)

    described_class.validate!(desired_state: desired_state, provider_registry: registry)

    expect(provider).to have_received(:validate).with(resource: { provider: 'echo', type: 'user', name: 'alice' })
    expect(provider).to have_received(:validate).with(resource: { provider: 'echo', type: 'user', name: 'bob' })
  end

  it 'raises when provider returns ok: false validation result' do
    provider = instance_double(Umgr::Providers::EchoProvider)
    registry = instance_double(Umgr::ProviderRegistry)
    desired_state = {
      resources: [
        { provider: 'echo', type: 'user', name: 'alice', identity: 'echo.user.alice' }
      ]
    }

    allow(registry).to receive(:fetch).with('echo').and_return(provider)
    allow(provider).to receive(:validate).and_return(ok: false, error: 'provider validation failed')

    expect do
      described_class.validate!(desired_state: desired_state, provider_registry: registry)
    end.to raise_error(Umgr::Errors::ValidationError, /provider validation failed for resource echo\.user\.alice/)
  end
end
