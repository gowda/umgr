# frozen_string_literal: true

RSpec.describe Umgr::Providers::GithubProvider do
  subject(:provider) { described_class.new(api_client: api_client) }

  let(:api_client) { instance_double(Umgr::Providers::GithubApiClient) }

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

  it 'imports current users and team memberships into canonical resources' do
    allow(api_client).to receive(:list_org_users).with(org: 'acme', token: 'secret').and_return(
      [
        {
          'id' => 10,
          'login' => 'alice',
          'avatar_url' => 'https://avatars.example/alice',
          'html_url' => 'https://github.com/alice',
          'type' => 'User'
        }
      ]
    )
    allow(api_client).to receive(:list_org_team_memberships).with(org: 'acme', token: 'secret').and_return(
      { 'alice' => %w[platform admins] }
    )

    result = provider.current(resource: resource.merge(token: 'secret'))

    expect(result[:ok]).to eq(true)
    expect(result[:provider]).to eq('github')
    expect(result[:org]).to eq('acme')
    expect(result[:count]).to eq(1)
    expect(result[:imported_accounts]).to eq(
      [
        {
          provider: 'github',
          type: 'user',
          name: 'alice',
          identity: 'github.user.alice',
          org: 'acme',
          teams: %w[admins platform],
          attributes: {
            id: 10,
            login: 'alice',
            avatar_url: 'https://avatars.example/alice',
            html_url: 'https://github.com/alice',
            type: 'User'
          }
        }
      ]
    )
  end

  it 'uses token_env when token is not provided' do
    allow(ENV).to receive(:fetch).with('GITHUB_TOKEN', nil).and_return('from-env')
    allow(api_client).to receive(:list_org_users).with(org: 'acme', token: 'from-env').and_return([])
    allow(api_client).to receive(:list_org_team_memberships).with(org: 'acme', token: 'from-env').and_return({})

    result = provider.current(resource: resource)

    expect(result[:ok]).to eq(true)
    expect(result[:count]).to eq(0)
  end

  it 'raises when token_env is configured but not present in environment' do
    allow(ENV).to receive(:fetch).with('GITHUB_TOKEN', nil).and_return(nil)

    expect { provider.current(resource: resource) }
      .to raise_error(Umgr::Errors::ValidationError, /token_env.*is not set/)
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
