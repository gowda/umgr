# frozen_string_literal: true

module Umgr
  module RunnerConfig
    DSL_SOURCE = DslCompiler::DEFAULT_DSL_PATH
    AUTO_DISCOVERY_CONFIGS = %w[umgr.yml umgr.yaml umgr.json].freeze

    private

    def with_resolved_config(action, options)
      resolved_options = options.dup
      config_input = resolve_config_input(action, options[:config])
      return missing_config_error(action) unless config_input

      if config_input[:type] == :file
        return with_validated_config_options(action, resolved_options, config_input.fetch(:path))
      end

      with_validated_stdin_options(action, resolved_options, config_input.fetch(:content))
    end

    def missing_config_error(action)
      supported = AUTO_DISCOVERY_CONFIGS.join(', ')
      raise Errors::ValidationError, "`config` is required for #{action}. Auto-discovery checks: #{supported}"
    end

    def with_validated_config_options(action, resolved_options, resolved)
      desired_state = ensure_valid_config(resolved)
      validate_desired_state!(action: action, desired_state: desired_state)
      resolved_options.merge(config: resolved, desired_state: desired_state)
    end

    def with_validated_stdin_options(action, resolved_options, content)
      desired_state = ensure_valid_config_content(content)
      validate_desired_state!(action: action, desired_state: desired_state)
      resolved_options.merge(config: '-', desired_state: desired_state)
    end

    def resolve_config_input(action, config_path)
      return { type: :stdin, content: $stdin.read } if config_path == '-'
      return { type: :file, path: explicit_config_path(config_path) } if config_path && !config_path.empty?

      discovered_path = discover_config_path
      return { type: :file, path: discovered_path } if discovered_path

      return nil unless File.file?(File.expand_path(DSL_SOURCE))

      raise Errors::ValidationError,
            "No auto-discovered config for #{action}. Found #{DSL_SOURCE}; compile first: " \
            "umgr compile | umgr #{action} --config -"
    end

    def explicit_config_path(config_path)
      absolute_path = File.expand_path(config_path)
      return absolute_path if File.file?(absolute_path)

      raise Errors::ValidationError, "Config file not found: #{config_path}"
    end

    def discover_config_path
      discovered_paths = AUTO_DISCOVERY_CONFIGS.filter_map do |candidate|
        absolute_path = File.expand_path(candidate)
        absolute_path if File.file?(absolute_path)
      end

      return if discovered_paths.empty?
      return discovered_paths.first unless File.file?(File.expand_path(DSL_SOURCE))

      ambiguity_error(discovered_paths)
    end

    def ambiguity_error(discovered_paths)
      configs = discovered_paths.map { |path| File.basename(path) }.join(', ')
      raise Errors::ValidationError,
            "Auto-discovery ambiguity: found #{DSL_SOURCE} and #{configs}. " \
            'Use --config <path> or compile pipeline (--config -).'
    end

    def ensure_valid_config(config_path)
      desired_state = DeepSymbolizer.call(ConfigValidator.validated_config(config_path))
      DesiredStateEnricher.call(desired_state)
    end

    def ensure_valid_config_content(content)
      desired_state = DeepSymbolizer.call(ConfigValidator.validated_content(content))
      DesiredStateEnricher.call(desired_state)
    end

    def validate_desired_state!(action:, desired_state:)
      UnknownProviderGuard.validate!(desired_state: desired_state, action: action, provider_registry: provider_registry)
      ProviderResourceValidator.validate!(desired_state: desired_state, provider_registry: provider_registry)
    end

    def resolve_dsl_path(path)
      dsl_path = File.expand_path(path.to_s.empty? ? DSL_SOURCE : path)
      return dsl_path if File.file?(dsl_path)

      raise Errors::ValidationError, "DSL file not found: #{path.to_s.empty? ? DSL_SOURCE : path}"
    end
  end
end
