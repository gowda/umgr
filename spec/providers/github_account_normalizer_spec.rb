# frozen_string_literal: true

RSpec.describe Umgr::Providers::GithubAccountNormalizer do
  it 'normalizes github user payload into canonical account resource shape' do
    user = {
      'id' => 10,
      'login' => 'alice',
      'avatar_url' => 'https://avatars.example/alice',
      'html_url' => 'https://github.com/alice',
      'type' => 'User'
    }

    result = described_class.call(user: user, org: 'acme', teams: %w[admins platform])

    expect(result).to eq(
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
    )
  end
end
