# frozen_string_literal: true

module Umgr
  module Providers
    class GithubProvider < Provider
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
        {
          ok: false,
          provider: 'github',
          status: 'not_implemented',
          resource: resource
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
    end
  end
end
