# frozen_string_literal: true

require 'json'

RSpec.describe Umgr::Providers::GithubApiClient do
  subject(:client) { described_class.new }

  it 'paginates org users with link headers' do
    stub_request(:get, %r{\Ahttps://api\.github\.com/orgs/acme/members(\?.*)?\z}).to_return(
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
    stub_request(:get, %r{\Ahttps://api\.github\.com/orgs/acme/teams(\?.*)?\z}).to_return(
      status: 200,
      body: JSON.generate([{ id: 101, slug: 'platform' }, { id: 102, slug: 'admins' }]),
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:get, %r{\Ahttps://api\.github\.com/teams/101/members(\?.*)?\z}).to_return(
      status: 200,
      body: JSON.generate([{ login: 'alice' }, { login: 'bob' }]),
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:get, %r{\Ahttps://api\.github\.com/teams/102/members(\?.*)?\z}).to_return(
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
    stub_request(:get, %r{\Ahttps://api\.github\.com/orgs/acme/members(\?.*)?\z}).to_return(
      status: 500,
      body: JSON.generate(message: 'internal error'),
      headers: { 'Content-Type' => 'application/json' }
    )

    expect { client.list_org_users(org: 'acme', token: 'secret') }
      .to raise_error(Umgr::Errors::ApiError, /GitHub API request failed/)
  end

  it 'invites user to organization membership' do
    stub_request(:put, 'https://api.github.com/orgs/acme/memberships/alice')
      .with(body: hash_including(role: 'member'))
      .to_return(status: 200, body: JSON.generate(state: 'pending'), headers: { 'Content-Type' => 'application/json' })

    result = client.invite_org_member(org: 'acme', login: 'alice', token: 'secret')

    expect(result[:state] || result['state']).to eq('pending')
  end

  it 'adds and removes team membership by slug' do
    stub_request(:get, %r{\Ahttps://api\.github\.com/orgs/acme/teams(\?.*)?\z}).to_return(
      status: 200,
      body: JSON.generate([{ id: 101, slug: 'platform' }]),
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:put, 'https://api.github.com/teams/101/memberships/alice').to_return(
      status: 200,
      body: JSON.generate(state: 'active'),
      headers: { 'Content-Type' => 'application/json' }
    )
    stub_request(:delete, 'https://api.github.com/teams/101/memberships/alice').to_return(status: 204, body: '')

    add_result = client.add_team_membership(org: 'acme', team_slug: 'platform', login: 'alice', token: 'secret')
    remove_result = client.remove_team_membership(org: 'acme', team_slug: 'platform', login: 'alice', token: 'secret')

    expect(add_result[:state] || add_result['state']).to eq('active')
    expect(remove_result).to eq(true)
  end

  it 'removes organization membership' do
    stub_request(:delete, 'https://api.github.com/orgs/acme/memberships/alice').to_return(status: 204, body: '')

    result = client.remove_org_member(org: 'acme', login: 'alice', token: 'secret')

    expect(result).to eq(true)
  end
end
