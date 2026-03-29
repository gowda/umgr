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
  end

  it 'falls back to shared initial state when no persisted state exists' do
    allow(state_backend).to receive(:read).and_return(nil)

    result = described_class.call(state_backend: state_backend, options: options)

    expect(result[:status]).to eq('planned')
    expect(result[:current_state]).to eq(Umgr::StateTemplate::INITIAL_STATE)
    expect(result[:changeset][:summary]).to eq(create: 1, update: 0, delete: 0, no_change: 0)
  end
end
