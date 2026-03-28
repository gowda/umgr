# frozen_string_literal: true

module Umgr
  class Runner
    ACTIONS = %i[init validate plan apply show import].freeze
    AUTO_DISCOVERY_CONFIGS = %w[umgr.yml umgr.yaml umgr.json].freeze
    INITIAL_STATE = { version: 1, resources: [].freeze }.freeze

    def initialize(state_backend: nil)
      @state_backend = state_backend || StateBackend.new
    end

    def ping
      :ok
    end

    # rubocop:disable Style/ArgumentsForwarding
    def dispatch(action, **options)
      action_name = action.to_sym
      raise Errors::UnknownActionError, "Unknown action: #{action}" unless ACTIONS.include?(action_name)

      send(action_name, **options)
    end
    # rubocop:enable Style/ArgumentsForwarding

    private

    def init(**options)
      existing_state = state_backend.read
      return completed(:init, 'already_initialized', options, existing_state) if existing_state

      state_backend.write(INITIAL_STATE)
      completed(:init, 'initialized', options, INITIAL_STATE)
    end

    def validate(**options)
      resolved_options = with_resolved_config(:validate, options)
      not_implemented(:validate, resolved_options)
    end

    def plan(**options)
      resolved_options = with_resolved_config(:plan, options)
      not_implemented(:plan, resolved_options)
    end

    def apply(**options)
      resolved_options = with_resolved_config(:apply, options)
      not_implemented(:apply, resolved_options)
    end

    def show(**options)
      not_implemented(:show, options)
    end

    def import(**options)
      resolved_options = with_resolved_config(:import, options)
      not_implemented(:import, resolved_options)
    end

    def not_implemented(action, options)
      {
        ok: false,
        action: action.to_s,
        status: 'not_implemented',
        options: options,
        state_path: state_backend.path
      }
    end

    def completed(action, status, options, state)
      {
        ok: true,
        action: action.to_s,
        status: status,
        options: options,
        state_path: state_backend.path,
        state: state
      }
    end

    def with_resolved_config(action, options)
      resolved_options = options.dup
      resolved = resolve_config_path(options[:config])
      if resolved
        desired_state = ensure_valid_config(resolved)
        return resolved_options.merge(config: resolved, desired_state: desired_state)
      end

      supported = AUTO_DISCOVERY_CONFIGS.join(', ')
      raise Errors::ValidationError, "`config` is required for #{action}. Auto-discovery checks: #{supported}"
    end

    def resolve_config_path(config_path)
      return explicit_config_path(config_path) if config_path && !config_path.empty?

      discover_config_path
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
      DeepSymbolizer.call(ConfigValidator.validated_config(config_path))
    end

    attr_reader :state_backend
  end
end
