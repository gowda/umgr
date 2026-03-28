# frozen_string_literal: true

module Umgr
  module ProviderContract
    METHODS = %i[validate current plan apply].freeze

    module_function

    def validate!(provider)
      missing_methods = METHODS.reject { |method_name| provider.respond_to?(method_name) }
      return provider if missing_methods.empty?

      raise ArgumentError, "Provider #{provider.class} must implement: #{missing_methods.join(', ')}"
    end
  end
end
