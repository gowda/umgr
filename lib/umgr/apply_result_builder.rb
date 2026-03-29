# frozen_string_literal: true

module Umgr
  # rubocop:disable Metrics/ModuleLength
  module ApplyResultBuilder
    module_function

    def call(state_backend:, options:, provider_registry:)
      previous_state = state_backend.read
      state_written = false
      write_state_and_build_result(state_backend, options, provider_registry) { state_written = true }
    rescue StandardError => e
      attempt_rollback(state_backend, previous_state) if state_written
      raise e
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

    def write_state_and_build_result(state_backend, options, provider_registry)
      desired_state = options.fetch(:desired_state)
      plan_result = plan_result_for(state_backend, options, provider_registry)
      apply_results = apply_changes(plan_result.fetch(:changeset).fetch(:changes), provider_registry)
      final_state = build_final_state(desired_state)
      state_backend.write(final_state)
      yield if block_given?
      idempotency = verify_idempotency(state_backend, options, provider_registry)
      payload = result_payload(plan_result, apply_results, idempotency)
      build_result(options: options, state_backend: state_backend, final_state: final_state, payload: payload)
    end

    def plan_result_for(state_backend, options, provider_registry)
      PlanResultBuilder.call(state_backend: state_backend, options: options, provider_registry: provider_registry)
    end

    def rollback_state(state_backend, previous_state)
      if previous_state
        state_backend.write(previous_state)
      else
        state_backend.delete
      end
    end

    def attempt_rollback(state_backend, previous_state)
      rollback_state(state_backend, previous_state)
    rescue StandardError => e
      warn(
        "Rollback failed after apply error (#{e.class}: #{e.message}); " \
        'original apply error preserved'
      )
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

    def verify_idempotency(state_backend, options, provider_registry)
      post_apply_plan = plan_result_for(state_backend, options, provider_registry)
      summary = post_apply_plan.fetch(:changeset).fetch(:summary)
      return { checked: true, stable: true, summary: summary } if idempotent_summary?(summary)

      raise Errors::InternalError, "Apply is not idempotent; pending changes remain: #{summary}"
    end

    def idempotent_summary?(summary)
      summary.fetch(:create).zero? && summary.fetch(:update).zero? && summary.fetch(:delete).zero?
    end

    def result_payload(plan_result, apply_results, idempotency)
      {
        changeset: plan_result.fetch(:changeset),
        drift: plan_result.fetch(:drift),
        apply_results: apply_results,
        idempotency: idempotency
      }
    end

    def build_result(options:, state_backend:, final_state:, payload:)
      base_result(options, state_backend, final_state).merge(
        payload
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
  # rubocop:enable Metrics/ModuleLength
end
