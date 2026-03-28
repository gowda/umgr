# frozen_string_literal: true

module Umgr
  module UnknownProviderGuard
    module_function

    def validate!(desired_state:, action:, provider_registry:)
      resources = desired_state.fetch(:resources, [])
      providers = resources.map { |resource| resource[:provider] }.uniq
      unknown_providers = providers.reject { |provider| provider_registry.fetch(provider) }

      return if unknown_providers.empty?

      joined = unknown_providers.map(&:to_s).sort.join(', ')
      raise Errors::ValidationError, "Unknown provider(s) for #{action}: #{joined}"
    end
  end
end
