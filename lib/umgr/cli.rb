# frozen_string_literal: true

require 'json'
require 'thor'

module Umgr
  class CLI < Thor
    desc 'version', 'Print umgr version'
    def version
      puts Umgr::VERSION
    end

    desc 'help [COMMAND]', 'Describe available commands or one specific command'
    def help(command = nil)
      super
    end

    desc 'init', 'Initialize umgr state'
    def init
      execute(:init)
    end

    desc 'validate', 'Validate configuration'
    option :config, type: :string, desc: 'Path to config file'
    def validate
      execute(:validate, **command_options)
    end

    desc 'plan', 'Generate plan from desired state'
    option :config, type: :string, desc: 'Path to config file'
    def plan
      execute(:plan, **command_options)
    end

    desc 'apply', 'Apply desired state'
    option :config, type: :string, desc: 'Path to config file'
    def apply
      execute(:apply, **command_options)
    end

    desc 'show', 'Show current state'
    def show
      execute(:show)
    end

    desc 'import', 'Import current users from providers'
    option :config, type: :string, desc: 'Path to config file'
    def import
      execute(:import, **command_options)
    end

    private

    def runner
      @runner ||= Umgr::Runner.new
    end

    def command_options
      options.to_h.transform_keys(&:to_sym)
    end

    def render_result(result)
      puts JSON.generate(result)
    end

    # rubocop:disable Style/ArgumentsForwarding
    def execute(action, **options)
      render_result(runner.dispatch(action, **options))
    rescue Errors::Error => e
      render_error(e)
      exit(e.exit_code)
    rescue StandardError => e
      internal = Errors::InternalError.new(e.message)
      render_error(internal)
      exit(internal.exit_code)
    end
    # rubocop:enable Style/ArgumentsForwarding

    def render_error(error)
      warn JSON.generate(
        {
          ok: false,
          error: {
            type: error.class.name,
            message: error.message
          }
        }
      )
    end
  end
end
