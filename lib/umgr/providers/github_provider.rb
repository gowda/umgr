# frozen_string_literal: true

module Umgr
  module Providers
    class GithubProvider < Provider
      def initialize(api_client: nil)
        super()
        @api_client = api_client || GithubApiClient.new
      end

      def validate(resource:)
        validate_org!(resource)
        validate_auth!(resource)
        validate_teams!(resource)

        {
          ok: true,
          provider: 'github',
          resource: resource
        }
      end

      def current(resource:)
        validate(resource: resource)
        org = resource.fetch(:org)
        token = resolve_token!(resource)
        accounts = import_accounts(org: org, token: token)
        current_result(org: org, accounts: accounts)
      end

      def current_result(org:, accounts:)
        {
          ok: true,
          provider: 'github',
          org: org,
          imported_accounts: accounts,
          count: accounts.length
        }
      end

      def plan(desired:, current:)
        {
          ok: false,
          provider: 'github',
          status: 'not_implemented',
          desired: desired,
          current: current
        }
      end

      def apply(changeset:)
        {
          ok: false,
          provider: 'github',
          status: 'not_implemented',
          changeset: changeset
        }
      end

      private

      attr_reader :api_client

      def validate_org!(resource)
        org = resource[:org]
        return if org.is_a?(String) && !org.strip.empty?

        raise Errors::ValidationError, 'GitHub provider requires non-empty `org`'
      end

      def validate_auth!(resource)
        token = resource[:token]
        token_env = resource[:token_env]
        return if present_string?(token) || present_string?(token_env)

        raise Errors::ValidationError, 'GitHub provider requires `token` or `token_env`'
      end

      def validate_teams!(resource)
        teams = resource[:teams]
        return if teams.nil?
        return if teams.is_a?(Array) && teams.all? { |team| present_string?(team) }

        raise Errors::ValidationError, 'GitHub provider `teams` must be an array of non-empty strings'
      end

      def present_string?(value)
        value.is_a?(String) && !value.strip.empty?
      end

      def resolve_token!(resource)
        return resource[:token] if present_string?(resource[:token])

        env_name = resource[:token_env]
        env_token = ENV.fetch(env_name, nil)
        return env_token if present_string?(env_token)

        raise Errors::ValidationError, "GitHub provider `token_env` #{env_name} is not set"
      end

      def import_accounts(org:, token:)
        users = api_client.list_org_users(org: org, token: token)
        memberships = api_client.list_org_team_memberships(org: org, token: token)
        users.map do |user|
          login = fetch_login(user)
          teams = memberships.fetch(login, [])
          GithubAccountNormalizer.call(user: user, org: org, teams: teams)
        end
      end

      def fetch_login(user)
        login = user[:login] if user.respond_to?(:[])
        login ||= user['login'] if user.respond_to?(:[])
        login ||= user.login if user.respond_to?(:login)
        return login if present_string?(login)

        raise Errors::ApiError, 'GitHub API response missing user login'
      end
    end
  end
end
