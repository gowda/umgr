# frozen_string_literal: true

module Umgr
  module Providers
    module GithubAccountNormalizer
      module_function

      def call(user:, org:, teams:)
        resource = base_resource(user)
        resource.merge(
          identity: ResourceIdentity.call(resource),
          org: org,
          teams: teams.sort,
          attributes: normalized_attributes(user)
        )
      end

      def normalized_attributes(user)
        {
          id: user['id'],
          login: user['login'],
          avatar_url: user['avatar_url'],
          html_url: user['html_url'],
          type: user['type']
        }.compact
      end

      def base_resource(user)
        {
          provider: 'github',
          type: 'user',
          name: user.fetch('login')
        }
      end
    end
  end
end
