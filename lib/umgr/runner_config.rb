# frozen_string_literal: true

module Umgr
  module RunnerConfig
    AUTO_DISCOVERY_CONFIGS = %w[umgr.yml umgr.yaml umgr.json].freeze

    private

    def with_resolved_config(action, options)
      resolved_options = options.dup
      resolved = resolve_config_path(options[:config])
      if resolved
        with_validated_config_options(action, resolved_options, resolved)
      else
        supported = AUTO_DISCOVERY_CONFIGS.join(', ')
        raise Errors::ValidationError, "`config` is required for #{action}. Auto-discovery checks: #{supported}"
      end
    end

    def with_validated_config_options(action, resolved_options, resolved)
      desired_state = ensure_valid_config(resolved)
      UnknownProviderGuard.validate!(desired_state: desired_state, action: action, provider_registry: provider_registry)
      ProviderResourceValidator.validate!(desired_state: desired_state, provider_registry: provider_registry)
      resolved_options.merge(config: resolved, desired_state: desired_state)
    end

    def resolve_config_path(config_path)
      config_path && !config_path.empty? ? explicit_config_path(config_path) : discover_config_path
    end

    def explicit_config_path(config_path)
      absolute_path = File.expand_path(config_path)
      return absolute_path if File.file?(absolute_path)

      raise Errors::ValidationError, "Config file not found: #{config_path}"
    end

    def discover_config_path
      AUTO_DISCOVERY_CONFIGS.each do |candidate|
        absolute_path = File.expand_path(candidate)
        return absolute_path if File.file?(absolute_path)
      end

      nil
    end

    def ensure_valid_config(config_path)
      desired_state = DeepSymbolizer.call(ConfigValidator.validated_config(config_path))
      DesiredStateEnricher.call(desired_state)
    end
  end
end
