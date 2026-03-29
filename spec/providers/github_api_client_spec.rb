# frozen_string_literal: true

require 'json'

RSpec.describe Umgr::Providers::GithubApiClient do
  subject(:client) { described_class.new }

  it 'paginates org users with link headers' do
    stub_request(:get, %r{\Ahttps://api.github.com/orgs/acme/members(\?.*)?\z}).to_return(
      status: 200,
      body: JSON.generate([{ login: 'alice' }]),
      headers: {
        'Content-Type' => 'application/json',
        'Link' => '<https://api.github.com/orgs/acme/members?page=2>; rel="next"'
      }
    )
    stub_request(:get, 'https://api.github.com/orgs/acme/members?page=2').to_return(
      status: 200,
      body: JSON.generate([{ login: 'bob' }]),
      headers: { 'Content-Type' => 'application/json' }
    )

    result = client.list_org_users(org: 'acme', token: 'secret')

    expect(result.map { |user| user[:login] || user['login'] }).to eq(%w[alice bob])
  end

  it 'builds team memberships map from org teams and members endpoints' do
    stub_request(:get, %r{\Ahttps://api.github.com/orgs/acme/teams(\?.*)?\z}).to_return(
      status: 200,
      body: JSON.generate([{ id: 101, slug: 'platform' }, { id: 102, slug: 'admins' }]),
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:get, %r{\Ahttps://api.github.com/teams/101/members(\?.*)?\z}).to_return(
      status: 200,
      body: JSON.generate([{ login: 'alice' }, { login: 'bob' }]),
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:get, %r{\Ahttps://api.github.com/teams/102/members(\?.*)?\z}).to_return(
      status: 200,
      body: JSON.generate([{ login: 'alice' }]),
      headers: { 'Content-Type' => 'application/json' }
    )

    result = client.list_org_team_memberships(org: 'acme', token: 'secret')

    expect(result).to eq(
      'alice' => %w[admins platform],
      'bob' => ['platform']
    )
  end

  it 'raises api error on non-success responses' do
    stub_request(:get, %r{\Ahttps://api.github.com/orgs/acme/members(\?.*)?\z}).to_return(
      status: 500,
      body: JSON.generate(message: 'internal error'),
      headers: { 'Content-Type' => 'application/json' }
    )

    expect { client.list_org_users(org: 'acme', token: 'secret') }
      .to raise_error(Umgr::Errors::ApiError, /GitHub API request failed/)
  end
end
