# frozen_string_literal: true

module Umgr
  module DesiredStateEnricher
    module_function

    def call(desired_state)
      resources = desired_state.fetch(:resources, []).map do |resource|
        resource.merge(identity: ResourceIdentity.call(resource))
      end

      desired_state.merge(resources: resources)
    end
  end
end
