# frozen_string_literal: true

module Umgr
  module PlanResultBuilder
    module_function

    def call(state_backend:, options:)
      desired_state = options.fetch(:desired_state)
      current_state = DesiredStateEnricher.call(state_backend.read || StateTemplate::INITIAL_STATE)
      changeset = build_changeset(desired_state: desired_state, current_state: current_state)
      build_result(options: options, state_backend: state_backend, current_state: current_state, changeset: changeset)
    end

    def build_changeset(desired_state:, current_state:)
      ChangeSetBuilder.call(
        desired_resources: desired_state.fetch(:resources, []),
        current_resources: current_state.fetch(:resources, [])
      )
    end

    def build_result(options:, state_backend:, current_state:, changeset:)
      result = { ok: true, action: 'plan', status: 'planned', options: options, state_path: state_backend.path }
      result.merge(current_state: current_state, changeset: changeset)
    end
  end
end
