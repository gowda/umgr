# frozen_string_literal: true

module Umgr
  module ProviderResourceValidator
    module_function

    def validate!(desired_state:, provider_registry:)
      desired_state.fetch(:resources, []).each do |resource|
        provider = provider_registry.fetch(resource[:provider])
        result = provider.validate(resource: resource)
        raise_validation_error!(provider: provider, resource: resource, result: result) if invalid_result?(result)
      end
    end

    def invalid_result?(result)
      return false unless result.is_a?(Hash)

      result[:ok] == false || result['ok'] == false
    end

    def raise_validation_error!(provider:, resource:, result:)
      message = result[:error] || result['error'] || "Provider #{provider.class} validation returned `ok: false`"
      identity = resource[:identity] || ResourceIdentity.call(resource)
      raise Errors::ValidationError, "#{message} for resource #{identity}"
    end
  end
end
