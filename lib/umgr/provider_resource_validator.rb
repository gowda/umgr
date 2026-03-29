# frozen_string_literal: true

module Umgr
  module ProviderResourceValidator
    module_function

    def validate!(desired_state:, provider_registry:)
      desired_state.fetch(:resources, []).each do |resource|
        provider_registry.fetch(resource[:provider]).validate(resource: resource)
      end
    end
  end
end
