# frozen_string_literal: true

require_relative 'umgr/version'
require_relative 'umgr/errors'
require_relative 'umgr/config_validator'
require_relative 'umgr/deep_symbolizer'
require_relative 'umgr/resource_identity'
require_relative 'umgr/desired_state_enricher'
require_relative 'umgr/state_template'
require_relative 'umgr/change_set_builder'
require_relative 'umgr/plan_result_builder'
require_relative 'umgr/provider'
require_relative 'umgr/provider_contract'
require_relative 'umgr/providers/echo_provider'
require_relative 'umgr/provider_registry'
require_relative 'umgr/unknown_provider_guard'
require_relative 'umgr/state_backend'
require_relative 'umgr/runner'
require_relative 'umgr/cli'

module Umgr
end
