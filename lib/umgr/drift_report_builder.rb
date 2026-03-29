# frozen_string_literal: true

module Umgr
  module DriftReportBuilder
    DRIFT_ACTIONS = %i[create update delete].freeze

    module_function

    def call(summary)
      drift_counts = DRIFT_ACTIONS.to_h { |action| [action, summary.fetch(action, 0)] }
      change_count = drift_counts.values.sum
      {
        detected: change_count.positive?,
        change_count: change_count,
        actions: drift_counts
      }
    end
  end
end
