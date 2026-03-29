# frozen_string_literal: true

require 'json'

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

  it 'imports current users and team memberships into canonical resources' do
    stub_request(:get, %r{\Ahttps://api.github.com/orgs/acme/members(\?.*)?\z}).to_return(
      status: 200,
      body: JSON.generate(
        [
          {
            id: 10,
            login: 'alice',
            avatar_url: 'https://avatars.example/alice',
            html_url: 'https://github.com/alice',
            type: 'User'
          }
        ]
      ),
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:get, %r{\Ahttps://api.github.com/orgs/acme/teams(\?.*)?\z}).to_return(
      status: 200,
      body: JSON.generate([{ id: 101, slug: 'platform' }, { id: 102, slug: 'admins' }]),
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:get, %r{\Ahttps://api.github.com/teams/101/members(\?.*)?\z}).to_return(
      status: 200,
      body: JSON.generate([{ login: 'alice' }]),
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:get, %r{\Ahttps://api.github.com/teams/102/members(\?.*)?\z}).to_return(
      status: 200,
      body: JSON.generate([{ login: 'alice' }]),
      headers: { 'Content-Type' => 'application/json' }
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

  it 'raises api error when github api fails' do
    stub_request(:get, %r{\Ahttps://api.github.com/orgs/acme/members(\?.*)?\z}).to_return(
      status: 401,
      body: JSON.generate(message: 'Bad credentials'),
      headers: { 'Content-Type' => 'application/json' }
    )

    expect { provider.current(resource: resource.merge(token: 'secret')) }
      .to raise_error(Umgr::Errors::ApiError, /GitHub API request failed/)
  end

  it 'uses token_env when token is not provided' do
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:fetch).with('GITHUB_TOKEN', nil).and_return('from-env')
    stub_request(:get, %r{\Ahttps://api.github.com/orgs/acme/members(\?.*)?\z}).to_return(
      status: 200,
      body: JSON.generate([]),
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:get, %r{\Ahttps://api.github.com/orgs/acme/teams(\?.*)?\z}).to_return(
      status: 200,
      body: JSON.generate([]),
      headers: { 'Content-Type' => 'application/json' }
    )

    result = provider.current(resource: resource)

    expect(result[:ok]).to eq(true)
    expect(result[:count]).to eq(0)
  end

  it 'raises when token_env is configured but not present in environment' do
    allow(ENV).to receive(:fetch).and_call_original
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
