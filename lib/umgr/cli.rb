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
      render_result(runner.dispatch(:init))
    end

    desc 'validate', 'Validate configuration'
    option :config, type: :string, desc: 'Path to config file'
    def validate
      render_result(runner.dispatch(:validate, **command_options))
    end

    desc 'plan', 'Generate plan from desired state'
    option :config, type: :string, desc: 'Path to config file'
    def plan
      render_result(runner.dispatch(:plan, **command_options))
    end

    desc 'apply', 'Apply desired state'
    option :config, type: :string, desc: 'Path to config file'
    def apply
      render_result(runner.dispatch(:apply, **command_options))
    end

    desc 'show', 'Show current state'
    def show
      render_result(runner.dispatch(:show))
    end

    desc 'import', 'Import current users from providers'
    option :config, type: :string, desc: 'Path to config file'
    def import
      render_result(runner.dispatch(:import, **command_options))
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
  end
end
