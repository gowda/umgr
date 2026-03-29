# frozen_string_literal: true

module Umgr
  module Providers
    class EchoProvider < Provider
      def validate(resource:)
        {
          ok: true,
          provider: 'echo',
          resource: resource
        }
      end

      def current(resource:)
        {
          ok: true,
          provider: 'echo',
          account: resource.fetch(:attributes, {}),
          resource: resource
        }
      end

      def plan(desired:, current:)
        status = desired == current ? 'no_change' : 'update'
        {
          ok: true,
          provider: 'echo',
          status: status,
          desired: desired,
          current: current
        }
      end

      def apply(changeset:)
        {
          ok: true,
          provider: 'echo',
          status: 'applied',
          changeset: changeset
        }
      end
    end
  end
end
