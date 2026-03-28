# frozen_string_literal: true

module Umgr
  class Provider
    def validate(resource:)
      _ = resource
      raise Errors::AbstractMethodError, "#{self.class} must implement #validate(resource:)"
    end

    def current(resource:)
      _ = resource
      raise Errors::AbstractMethodError, "#{self.class} must implement #current(resource:)"
    end

    def plan(desired:, current:)
      _ = desired
      _ = current
      raise Errors::AbstractMethodError, "#{self.class} must implement #plan(desired:, current:)"
    end

    def apply(changeset:)
      _ = changeset
      raise Errors::AbstractMethodError, "#{self.class} must implement #apply(changeset:)"
    end
  end
end
