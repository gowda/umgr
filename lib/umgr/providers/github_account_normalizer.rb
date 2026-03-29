# frozen_string_literal: true

module Umgr
  module Providers
    module GithubAccountNormalizer
      module_function

      def call(user:, org:, teams:)
        login = fetch_value(user, :login)
        resource = base_resource(login: login)
        resource.merge(
          identity: ResourceIdentity.call(resource),
          org: org,
          teams: teams.sort,
          attributes: normalized_attributes(user)
        )
      end

      def normalized_attributes(user)
        {
          id: fetch_value(user, :id),
          login: fetch_value(user, :login),
          avatar_url: fetch_value(user, :avatar_url),
          html_url: fetch_value(user, :html_url),
          type: fetch_value(user, :type)
        }.compact
      end

      def base_resource(login:)
        {
          provider: 'github',
          type: 'user',
          name: login
        }
      end

      def fetch_value(payload, key)
        value = payload[key] if payload.respond_to?(:[])
        value ||= payload[key.to_s] if payload.respond_to?(:[])
        value ||= payload.public_send(key) if payload.respond_to?(key)
        value
      end
    end
  end
end
