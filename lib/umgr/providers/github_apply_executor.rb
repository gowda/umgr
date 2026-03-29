# frozen_string_literal: true

module Umgr
  module Providers
    module GithubApplyExecutor
      module_function

      def call(changeset:, api_client:, token_resolver:, present_string:, plan_resolver:)
        resource = changeset[:desired] || changeset[:current] || {}
        org = resource[:org] || resource['org']
        raise Errors::ValidationError, 'GitHub apply requires non-empty `org`' unless present_string.call(org)

        token = token_resolver.call(resource)
        operations = resolve_operations(changeset, plan_resolver)
        executed_operations = execute_operations(api_client, org, token, operations)
        apply_result(operations, executed_operations)
      end

      def resolve_operations(changeset, plan_resolver)
        provider_plan = changeset[:provider_plan] || changeset['provider_plan'] || {}
        operations = provider_plan[:operations] || provider_plan['operations']
        return operations if operations.is_a?(Array)

        plan_resolver.call(changeset[:desired], changeset[:current]).fetch(:operations)
      end

      def execute_operations(api_client, org, token, operations)
        operations.map do |operation|
          execute_operation(api_client, org, token, operation)
          operation
        end
      end

      def execute_operation(api_client, org, token, operation)
        dispatch_operation(api_client, org, token, normalize_operation(operation))
      end

      def dispatch_operation(api_client, org, token, operation)
        handler = operation_handlers(api_client, org, token)[operation[:type]]
        return handler.call(operation) if handler

        raise Errors::ValidationError, "Unsupported GitHub apply operation: #{operation[:type]}"
      end

      def operation_handlers(api_client, org, token)
        {
          'invite_org_member' => ->(operation) { invite_operation(api_client, org, token, operation) },
          'remove_org_member' => ->(operation) { remove_org_operation(api_client, org, token, operation) },
          'add_team_membership' => ->(operation) { add_team_operation(api_client, org, token, operation) },
          'remove_team_membership' => ->(operation) { remove_team_operation(api_client, org, token, operation) },
          'no_change' => ->(_operation) {}
        }
      end

      def invite_operation(api_client, org, token, operation)
        api_client.invite_org_member(org: org, login: operation[:login], token: token)
      end

      def remove_org_operation(api_client, org, token, operation)
        api_client.remove_org_member(org: org, login: operation[:login], token: token)
      end

      def add_team_operation(api_client, org, token, operation)
        api_client.add_team_membership(org: org, team_slug: operation[:team], login: operation[:login], token: token)
      end

      def remove_team_operation(api_client, org, token, operation)
        api_client.remove_team_membership(org: org, team_slug: operation[:team], login: operation[:login], token: token)
      end

      def normalize_operation(operation)
        {
          type: operation[:type] || operation['type'],
          login: operation[:login] || operation['login'],
          team: operation[:team] || operation['team']
        }
      end

      def apply_result(operations, executed_operations)
        {
          ok: true,
          provider: 'github',
          status: 'applied',
          operations: operations,
          executed_operations: executed_operations
        }
      end
    end
  end
end
