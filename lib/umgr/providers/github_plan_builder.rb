# frozen_string_literal: true

module Umgr
  module Providers
    module GithubPlanBuilder
      module_function

      def call(desired:, current:)
        team_actions = build_team_actions(desired: desired, current: current)
        login = extract_login(desired, current)
        organization_action = organization_action_for(desired: desired, current: current)
        operations = build_plan_operations(
          organization_action: organization_action,
          login: login,
          team_add: team_actions[:add],
          team_remove: team_actions[:remove]
        )

        plan_result(organization_action: organization_action, operations: operations, team_actions: team_actions)
      end

      def extract_teams(resource)
        return [] unless resource.is_a?(Hash)

        raw = resource[:teams] || resource['teams'] || []
        Array(raw).map(&:to_s).reject(&:empty?).uniq.sort
      end

      def extract_login(desired, current)
        resource = desired || current
        return nil unless resource.is_a?(Hash)

        login = resource[:name] || resource['name']
        login&.to_s
      end

      def organization_action_for(desired:, current:)
        return 'invite' if desired && !current
        return 'remove' if current && !desired

        'keep'
      end

      def build_team_actions(desired:, current:)
        desired_teams = extract_teams(desired)
        current_teams = extract_teams(current)
        {
          add: desired_teams - current_teams,
          remove: current_teams - desired_teams,
          unchanged: desired_teams & current_teams
        }
      end

      def plan_result(organization_action:, operations:, team_actions:)
        {
          ok: true,
          provider: 'github',
          status: operations.empty? ? 'no_change' : 'planned',
          organization_action: organization_action,
          team_actions: team_actions,
          operations: operations
        }
      end

      def build_plan_operations(organization_action:, login:, team_add:, team_remove:)
        case organization_action
        when 'invite'
          build_invite_operations(login: login, team_add: team_add)
        when 'remove'
          [{ type: 'remove_org_member', login: login }]
        else
          build_membership_operations(login: login, team_add: team_add, team_remove: team_remove)
        end
      end

      def build_invite_operations(login:, team_add:)
        operations = [{ type: 'invite_org_member', login: login }]
        operations.concat(team_add.map { |team| { type: 'add_team_membership', login: login, team: team } })
        operations
      end

      def build_membership_operations(login:, team_add:, team_remove:)
        operations = []
        operations.concat(team_add.map { |team| { type: 'add_team_membership', login: login, team: team } })
        operations.concat(team_remove.map { |team| { type: 'remove_team_membership', login: login, team: team } })
        operations = [{ type: 'no_change', login: login }] if operations.empty?
        operations
      end
    end
  end
end
