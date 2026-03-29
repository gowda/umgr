# frozen_string_literal: true

RSpec.describe Umgr::DesiredStateEnricher do
  it 'adds canonical identity for each resource in multi-resource desired state' do
    desired_state = {
      version: 1,
      resources: [
        { provider: 'echo', type: 'user', name: 'alice' },
        { provider: 'github', type: 'user', name: 'bob' }
      ]
    }

    result = described_class.call(desired_state)

    expect(result[:resources]).to eq(
      [
        { provider: 'echo', type: 'user', name: 'alice', identity: 'echo.user.alice' },
        { provider: 'github', type: 'user', name: 'bob', identity: 'github.user.bob' }
      ]
    )
  end

  it 'returns desired state unchanged when resources is empty' do
    desired_state = { version: 1, resources: [] }

    result = described_class.call(desired_state)

    expect(result).to eq(desired_state)
  end
end
