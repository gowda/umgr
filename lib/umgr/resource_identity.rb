# frozen_string_literal: true

module Umgr
  module ResourceIdentity
    module_function

    def call(resource)
      "#{resource.fetch(:provider)}.#{resource.fetch(:type)}.#{resource.fetch(:name)}"
    end
  end
end
