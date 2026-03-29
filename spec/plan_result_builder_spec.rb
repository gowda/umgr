# frozen_string_literal: true

RSpec.describe Umgr::PlanResultBuilder do
  let(:state_backend) { instance_double(Umgr::StateBackend, path: '/tmp/.umgr/state.json') }
  let(:desired_state) do
    {
      version: 1,
      resources: [
        { provider: 'echo', type: 'user', name: 'alice', identity: 'echo.user.alice' }
      ]
    }
  end
  let(:options) { { config: '/tmp/users.yml', desired_state: desired_state } }

  it 'uses persisted state when available' do
    allow(state_backend).to receive(:read).and_return(
      version: 1,
      resources: [{ provider: 'echo', type: 'user', name: 'alice', identity: 'echo.user.alice' }]
    )

    result = described_class.call(state_backend: state_backend, options: options)

    expect(result[:status]).to eq('planned')
    expect(result[:current_state][:resources].size).to eq(1)
    expect(result[:changeset][:summary]).to eq(create: 0, update: 0, delete: 0, no_change: 1)
    expect(result[:drift]).to eq(
      detected: false,
      change_count: 0,
      actions: { create: 0, update: 0, delete: 0 }
    )
  end

  it 'falls back to shared initial state when no persisted state exists' do
    allow(state_backend).to receive(:read).and_return(nil)

    result = described_class.call(state_backend: state_backend, options: options)

    expect(result[:status]).to eq('planned')
    expect(result[:current_state]).to eq(Umgr::StateTemplate::INITIAL_STATE)
    expect(result[:changeset][:summary]).to eq(create: 1, update: 0, delete: 0, no_change: 0)
    expect(result[:drift]).to eq(
      detected: true,
      change_count: 1,
      actions: { create: 1, update: 0, delete: 0 }
    )
  end

  it 'enriches changes with provider-specific plan details when registry is provided' do
    provider_registry = instance_double(Umgr::ProviderRegistry)
    provider = instance_double(Umgr::Providers::GithubProvider)
    desired = { provider: 'github', type: 'user', name: 'alice', identity: 'github.user.alice', teams: ['admins'] }
    current = { provider: 'github', type: 'user', name: 'alice', identity: 'github.user.alice', teams: ['platform'] }
    allow(state_backend).to receive(:read).and_return(version: 1, resources: [current])
    allow(provider_registry).to receive(:fetch).with('github').and_return(provider)
    allow(provider).to receive(:plan).with(desired: desired, current: current).and_return(
      ok: true,
      provider: 'github',
      status: 'planned',
      operations: [{ type: 'add_team_membership', team: 'admins', login: 'alice' }]
    )
    custom_options = { config: '/tmp/users.yml', desired_state: { version: 1, resources: [desired] } }

    result = described_class.call(
      state_backend: state_backend,
      options: custom_options,
      provider_registry: provider_registry
    )

    change = result.fetch(:changeset).fetch(:changes).first
    expect(change[:action]).to eq('update')
    expect(change.fetch(:provider_plan)).to eq(
      ok: true,
      provider: 'github',
      status: 'planned',
      operations: [{ type: 'add_team_membership', team: 'admins', login: 'alice' }]
    )
  end

  it 'keeps change unchanged when provider name cannot be resolved' do
    provider_registry = instance_double(Umgr::ProviderRegistry)
    change = { identity: 'unknown.user.alice', action: 'update', desired: nil, current: nil }

    result = described_class.send(:enrich_change, change, provider_registry)

    expect(result).to eq(change)
  end

  it 'keeps change unchanged when provider plan result is not includable' do
    provider_registry = instance_double(Umgr::ProviderRegistry)
    provider = instance_double(Umgr::Providers::GithubProvider)
    desired = { provider: 'github', type: 'user', name: 'alice', identity: 'github.user.alice', teams: [] }
    current = { provider: 'github', type: 'user', name: 'alice', identity: 'github.user.alice', teams: ['admins'] }
    change = { identity: 'github.user.alice', action: 'update', desired: desired, current: current }
    allow(provider_registry).to receive(:fetch).with('github').and_return(provider)
    allow(provider).to receive(:plan).with(desired: desired, current: current).and_return(ok: false, status: 'error')

    result = described_class.send(:enrich_change, change, provider_registry)

    expect(result).to eq(change)
  end
end
