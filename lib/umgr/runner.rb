# frozen_string_literal: true

module Umgr
  class Runner
    ACTIONS = %i[init validate plan apply show import].freeze

    def ping
      :ok
    end

    # rubocop:disable Style/ArgumentsForwarding
    def dispatch(action, **options)
      action_name = action.to_sym
      raise ArgumentError, "Unknown action: #{action}" unless ACTIONS.include?(action_name)

      send(action_name, **options)
    end
    # rubocop:enable Style/ArgumentsForwarding

    private

    def init(**options)
      not_implemented(:init, options)
    end

    def validate(**options)
      not_implemented(:validate, options)
    end

    def plan(**options)
      not_implemented(:plan, options)
    end

    def apply(**options)
      not_implemented(:apply, options)
    end

    def show(**options)
      not_implemented(:show, options)
    end

    def import(**options)
      not_implemented(:import, options)
    end

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
