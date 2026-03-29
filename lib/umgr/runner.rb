# frozen_string_literal: true

module Umgr
  class Runner
    include RunnerConfig

    ACTIONS = %i[init compile validate plan apply show import].freeze

    def initialize(state_backend: nil, provider_registry: nil)
      @state_backend = state_backend || StateBackend.new
      @provider_registry = provider_registry || ProviderRegistry.new
    end

    def ping = :ok

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
      if existing_state
        completed(:init, 'already_initialized', options, existing_state)
      else
        state_backend.write(StateTemplate::INITIAL_STATE)
        completed(:init, 'initialized', options, StateTemplate::INITIAL_STATE)
      end
    end

    def validate(**options)
      resolved_options = with_resolved_config(:validate, options)
      not_implemented(:validate, resolved_options)
    end

    def compile(**options)
      dsl_path = resolve_dsl_path(options[:dsl])
      compiled_config = DslCompiler.compile_file(dsl_path)
      desired_state = DesiredStateEnricher.call(DeepSymbolizer.call(compiled_config))
      validate_desired_state!(action: :compile, desired_state: desired_state)
      completed_compile(options.merge(dsl: dsl_path), compiled_config)
    end

    def plan(**options)
      resolved_options = with_resolved_config(:plan, options)
      PlanResultBuilder.call(
        state_backend: state_backend,
        options: resolved_options,
        provider_registry: provider_registry
      )
    end

    def apply(**options)
      resolved_options = with_resolved_config(:apply, options)
      ApplyResultBuilder.call(
        state_backend: state_backend,
        options: resolved_options,
        provider_registry: provider_registry
      )
    end

    def show(**options)
      state = state_backend.read
      completed(:show, state ? 'ok' : 'not_initialized', options, state)
    end

    def import(**options)
      resolved_options = with_resolved_config(:import, options)
      ImportResultBuilder.call(
        state_backend: state_backend,
        options: resolved_options,
        provider_registry: provider_registry
      )
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

    def completed_compile(options, config)
      {
        ok: true,
        action: 'compile',
        status: 'compiled',
        options: options,
        config: config
      }
    end

    attr_reader :state_backend, :provider_registry
  end
end
