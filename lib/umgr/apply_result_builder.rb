# frozen_string_literal: true

module Umgr
  module ApplyResultBuilder
    module_function

    def call(state_backend:, options:, provider_registry:)
      desired_state = options.fetch(:desired_state)
      plan_result = plan_result_for(state_backend, options, provider_registry)
      apply_results = apply_changes(plan_result.fetch(:changeset).fetch(:changes), provider_registry)
      final_state = build_final_state(desired_state)
      state_backend.write(final_state)
      build_result(options, state_backend, plan_result, final_state, apply_results)
    end

    def apply_changes(changes, provider_registry)
      changes.map { |change| apply_change(change, provider_registry) }
    end

    def apply_change(change, provider_registry)
      return skipped_change_result(change) if change[:action] == 'no_change'

      provider_name = provider_name_for(change)
      raise Errors::InternalError, "Missing provider for #{change.fetch(:identity)}" unless provider_name

      provider_result = provider_registry.fetch(provider_name).apply(changeset: change)
      ensure_successful_apply!(provider_result, change)
      applied_change_result(change, provider_name, provider_result)
    end

    def skipped_change_result(change)
      {
        identity: change.fetch(:identity),
        action: change.fetch(:action),
        status: 'skipped'
      }
    end

    def ensure_successful_apply!(provider_result, change)
      return unless apply_failed?(provider_result)

      message = provider_result[:error] || provider_result['error'] || 'unknown provider apply failure'
      raise Errors::InternalError, "Provider apply failed for #{change.fetch(:identity)}: #{message}"
    end

    def apply_failed?(provider_result)
      return false unless provider_result.is_a?(Hash)

      provider_result.fetch(:ok, provider_result.fetch('ok', true)) == false
    end

    def provider_name_for(change)
      resource = change[:desired] || change[:current]
      return nil unless resource

      resource[:provider] || resource['provider']
    end

    def build_final_state(desired_state)
      {
        version: desired_state.fetch(:version),
        resources: desired_state.fetch(:resources)
      }
    end

    def plan_result_for(state_backend, options, provider_registry)
      PlanResultBuilder.call(state_backend: state_backend, options: options, provider_registry: provider_registry)
    end

    def applied_change_result(change, provider_name, provider_result)
      {
        identity: change.fetch(:identity),
        action: change.fetch(:action),
        provider: provider_name.to_s,
        status: 'applied',
        provider_result: provider_result
      }
    end

    def build_result(options, state_backend, plan_result, final_state, apply_results)
      base_result(options, state_backend, final_state).merge(
        changeset: plan_result.fetch(:changeset),
        drift: plan_result.fetch(:drift),
        apply_results: apply_results
      )
    end

    def base_result(options, state_backend, final_state)
      {
        ok: true,
        action: 'apply',
        status: 'applied',
        options: options,
        state_path: state_backend.path,
        state: final_state
      }
    end
  end
end
