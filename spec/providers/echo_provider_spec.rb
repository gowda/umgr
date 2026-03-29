# frozen_string_literal: true

RSpec.describe Umgr::Providers::EchoProvider do
  subject(:provider) { described_class.new }

  let(:resource) do
    {
      provider: 'echo',
      type: 'user',
      name: 'alice',
      attributes: {
        email: 'alice@example.com',
        team: 'platform'
      }
    }
  end

  it 'echoes resource in validate' do
    result = provider.validate(resource: resource)

    expect(result[:ok]).to be(true)
    expect(result[:provider]).to eq('echo')
    expect(result[:resource]).to eq(resource)
  end

  it 'echoes account attributes in current' do
    result = provider.current(resource: resource)

    expect(result[:ok]).to be(true)
    expect(result[:account]).to eq(email: 'alice@example.com', team: 'platform')
  end

  it 'returns update status when desired and current differ' do
    result = provider.plan(desired: { email: 'alice@example.com' }, current: { email: 'old@example.com' })

    expect(result[:ok]).to be(true)
    expect(result[:status]).to eq('update')
  end

  it 'returns no_change status when desired and current are the same' do
    desired = { email: 'alice@example.com' }
    result = provider.plan(desired: desired, current: desired)

    expect(result[:ok]).to be(true)
    expect(result[:status]).to eq('no_change')
  end

  it 'echoes changeset in apply' do
    result = provider.apply(changeset: { action: 'update' })

    expect(result[:ok]).to be(true)
    expect(result[:status]).to eq('applied')
    expect(result[:changeset]).to eq(action: 'update')
  end
end
