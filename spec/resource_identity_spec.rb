# frozen_string_literal: true

RSpec.describe Umgr::ResourceIdentity do
  it 'builds canonical identity as provider.type.name' do
    resource = {
      provider: 'github',
      type: 'user',
      name: 'alice'
    }

    expect(described_class.call(resource)).to eq('github.user.alice')
  end
end
