# frozen_string_literal: true

RSpec.describe Umgr::ChangeSetBuilder do
  it 'generates create, update, delete, and no_change entries with summary' do
    desired_resources = [
      { identity: 'echo.user.alice', provider: 'echo', type: 'user', name: 'alice', attributes: { team: 'platform' } },
      { identity: 'echo.user.carla', provider: 'echo', type: 'user', name: 'carla' },
      { identity: 'echo.user.dana', provider: 'echo', type: 'user', name: 'dana' }
    ]
    current_resources = [
      { identity: 'echo.user.alice', provider: 'echo', type: 'user', name: 'alice', attributes: { team: 'infra' } },
      { identity: 'echo.user.bob', provider: 'echo', type: 'user', name: 'bob' },
      { identity: 'echo.user.dana', provider: 'echo', type: 'user', name: 'dana' }
    ]

    result = described_class.call(desired_resources: desired_resources, current_resources: current_resources)

    expect(result[:changes].map { |change| [change[:identity], change[:action]] }).to eq(
      [
        ['echo.user.alice', 'update'],
        ['echo.user.bob', 'delete'],
        ['echo.user.carla', 'create'],
        ['echo.user.dana', 'no_change']
      ]
    )
    expect(result[:summary]).to eq(create: 1, update: 1, delete: 1, no_change: 1)
  end
end
