# frozen_string_literal: true

module Umgr
  class Provider
    def validate(resource:)
      raise NotImplementedError, "#{self.class} must implement #validate(resource:)"
    end

    def current(resource:)
      raise NotImplementedError, "#{self.class} must implement #current(resource:)"
    end

    def plan(desired:, current:)
      raise NotImplementedError, "#{self.class} must implement #plan(desired:, current:)"
    end

    def apply(changeset:)
      raise NotImplementedError, "#{self.class} must implement #apply(changeset:)"
    end
  end
end
