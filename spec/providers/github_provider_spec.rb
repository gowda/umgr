# frozen_string_literal: true

RSpec.describe Umgr::Providers::GithubProvider do
  subject(:provider) { described_class.new }

  let(:resource) do
    {
      provider: 'github',
      type: 'user',
      name: 'alice',
      org: 'acme',
      token_env: 'GITHUB_TOKEN',
      teams: %w[platform admins]
    }
  end

  it 'validates provider-specific configuration' do
    result = provider.validate(resource: resource)

    expect(result[:ok]).to eq(true)
    expect(result[:provider]).to eq('github')
    expect(result[:resource]).to eq(resource)
  end

  it 'requires org' do
    invalid = resource.except(:org)

    expect { provider.validate(resource: invalid) }
      .to raise_error(Umgr::Errors::ValidationError, /requires non-empty `org`/)
  end

  it 'requires token or token_env' do
    invalid = resource.except(:token, :token_env)

    expect { provider.validate(resource: invalid) }
      .to raise_error(Umgr::Errors::ValidationError, /requires `token` or `token_env`/)
  end

  it 'validates teams as an array of non-empty strings' do
    invalid = resource.merge(teams: ['platform', ''])

    expect { provider.validate(resource: invalid) }
      .to raise_error(Umgr::Errors::ValidationError, /`teams` must be an array/)
  end

  it 'returns not_implemented status for current' do
    result = provider.current(resource: resource)

    expect(result[:ok]).to eq(false)
    expect(result[:status]).to eq('not_implemented')
  end

  it 'returns not_implemented status for plan' do
    result = provider.plan(desired: { name: 'alice' }, current: { name: 'alice' })

    expect(result[:ok]).to eq(false)
    expect(result[:status]).to eq('not_implemented')
  end

  it 'returns not_implemented status for apply' do
    result = provider.apply(changeset: { action: 'create' })

    expect(result[:ok]).to eq(false)
    expect(result[:status]).to eq('not_implemented')
  end
end
