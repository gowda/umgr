# frozen_string_literal: true

RSpec.describe Umgr::Providers::GithubPlanBuilder do
  describe '.call' do
    it 'plans invite and team membership additions for new users' do
      result = described_class.call(
        desired: { provider: 'github', type: 'user', name: 'alice', teams: %w[admins platform] },
        current: nil
      )

      expect(result).to include(
        ok: true,
        provider: 'github',
        status: 'planned',
        organization_action: 'invite'
      )
      expect(result.fetch(:operations)).to eq(
        [
          { type: 'invite_org_member', login: 'alice' },
          { type: 'add_team_membership', login: 'alice', team: 'admins' },
          { type: 'add_team_membership', login: 'alice', team: 'platform' }
        ]
      )
    end

    it 'plans no_change operation when memberships are identical' do
      result = described_class.call(
        desired: { provider: 'github', type: 'user', name: 'alice', teams: %w[platform admins] },
        current: { provider: 'github', type: 'user', name: 'alice', teams: %w[admins platform] }
      )

      expect(result.fetch(:organization_action)).to eq('keep')
      expect(result.fetch(:team_actions)).to eq(add: [], remove: [], unchanged: %w[admins platform])
      expect(result.fetch(:operations)).to eq([{ type: 'no_change', login: 'alice' }])
    end

    it 'plans org removal when user is not desired anymore' do
      result = described_class.call(
        desired: nil,
        current: { provider: 'github', type: 'user', name: 'alice', teams: ['admins'] }
      )

      expect(result.fetch(:organization_action)).to eq('remove')
      expect(result.fetch(:operations)).to eq([{ type: 'remove_org_member', login: 'alice' }])
    end
  end
end
