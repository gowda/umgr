# frozen_string_literal: true

module Umgr
  class Runner
    ACTIONS = %i[init validate plan apply show import].freeze

    def ping
      :ok
    end

    def dispatch(action, **options)
      action_name = action.to_sym
      raise ArgumentError, "Unknown action: #{action}" unless ACTIONS.include?(action_name)

      payload = options.dup
      public_send(action_name, **payload)
    end

    def init(**options)
      payload = options.dup
      not_implemented(:init, payload)
    end

    def validate(**options)
      payload = options.dup
      not_implemented(:validate, payload)
    end

    def plan(**options)
      payload = options.dup
      not_implemented(:plan, payload)
    end

    def apply(**options)
      payload = options.dup
      not_implemented(:apply, payload)
    end

    def show(**options)
      payload = options.dup
      not_implemented(:show, payload)
    end

    def import(**options)
      payload = options.dup
      not_implemented(:import, payload)
    end

    private

    def not_implemented(action, options)
      {
        ok: false,
        action: action.to_s,
        status: 'not_implemented',
        options: options
      }
    end
  end
end
