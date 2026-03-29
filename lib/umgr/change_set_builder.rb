# frozen_string_literal: true

module Umgr
  module ChangeSetBuilder
    ACTIONS = %w[create update delete no_change].freeze

    module_function

    def call(desired_resources:, current_resources:)
      desired_index = index_resources(desired_resources)
      current_index = index_resources(current_resources)
      identities = (desired_index.keys + current_index.keys).uniq.sort
      changes = build_changes(identities, desired_index, current_index)
      {
        changes: changes,
        summary: summarize(changes)
      }
    end

    def build_changes(identities, desired_index, current_index)
      identities.map do |identity|
        desired = desired_index[identity]
        current = current_index[identity]
        {
          identity: identity,
          action: action_for(desired: desired, current: current),
          desired: desired,
          current: current
        }
      end
    end

    def action_for(desired:, current:)
      return 'create' if desired && !current
      return 'delete' if current && !desired
      return 'no_change' if desired == current

      'update'
    end

    def summarize(changes)
      ACTIONS.to_h { |action| [action.to_sym, changes.count { |change| change[:action] == action }] }
    end

    def index_resources(resources)
      resources.to_h { |resource| [resource.fetch(:identity), resource] }
    end
  end
end
