# frozen_string_literal: true

module Umgr
  module ProviderContract
    METHODS = %i[validate current plan apply].freeze

    module_function

    def validate!(provider)
      invalid_methods = METHODS.reject do |method_name|
        provider.respond_to?(method_name) && provider.method(method_name).owner != Provider
      end
      return provider if invalid_methods.empty?

      raise ArgumentError, "Provider #{provider.class} must implement concrete methods: #{invalid_methods.join(', ')}"
    end
  end
end
