# frozen_string_literal: true

module Umgr
  class ProviderRegistry
    def initialize
      @providers = {}
      register(:echo, Providers::EchoProvider.new)
    end

    def register(name, provider)
      normalized_name = normalize_name(name)
      ProviderContract.validate!(provider)
      providers[normalized_name] = provider
    end

    def fetch(name)
      providers[normalize_name(name)]
    end

    def names
      providers.keys.sort
    end

    private

    attr_reader :providers

    def normalize_name(name)
      normalized = name.to_s.strip
      raise Errors::ValidationError, 'Provider name must be a non-empty string or symbol' if normalized.empty?

      normalized.to_sym
    end
  end
end
