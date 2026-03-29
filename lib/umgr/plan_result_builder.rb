# frozen_string_literal: true

module Umgr
  module PlanResultBuilder
    module_function

    def call(state_backend:, options:, provider_registry: nil)
      desired_state = options.fetch(:desired_state)
      current_state = DesiredStateEnricher.call(state_backend.read || StateTemplate::INITIAL_STATE)
      changeset = build_changeset(
        desired_state: desired_state,
        current_state: current_state,
        provider_registry: provider_registry
      )
      build_result(options: options, state_backend: state_backend, current_state: current_state, changeset: changeset)
    end

    def build_changeset(desired_state:, current_state:, provider_registry:)
      changeset = ChangeSetBuilder.call(
        desired_resources: desired_state.fetch(:resources, []),
        current_resources: current_state.fetch(:resources, [])
      )
      return changeset unless provider_registry

      changeset.merge(changes: enrich_changes(changeset.fetch(:changes), provider_registry))
    end

    def enrich_changes(changes, provider_registry)
      changes.map { |change| enrich_change(change, provider_registry) }
    end

    def enrich_change(change, provider_registry)
      provider_name = provider_name_for(change)
      return change unless provider_name

      provider = provider_registry.fetch(provider_name)
      provider_result = provider.plan(desired: change[:desired], current: change[:current])
      return change unless include_provider_plan?(provider_result)

      change.merge(provider_plan: compact_provider_plan(provider_result))
    end

    def provider_name_for(change)
      resource = change[:desired] || change[:current]
      return nil unless resource

      resource[:provider] || resource['provider']
    end

    def include_provider_plan?(provider_result)
      return false unless provider_result.is_a?(Hash)

      provider_result.fetch(:ok, provider_result.fetch('ok', nil)) != false
    end

    def compact_provider_plan(provider_result)
      compacted = provider_result.dup
      %i[desired current].each { |key| compacted.delete(key) }
      %w[desired current].each { |key| compacted.delete(key) }
      compacted
    end

    def build_result(options:, state_backend:, current_state:, changeset:)
      result = { ok: true, action: 'plan', status: 'planned', options: options, state_path: state_backend.path }
      result.merge(
        current_state: current_state,
        changeset: changeset,
        drift: DriftReportBuilder.call(changeset.fetch(:summary))
      )
    end
  end
end
