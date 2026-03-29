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
    option :json, type: :boolean, default: false, desc: 'Render plan output as JSON'
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

    def render_result(action, result, options)
      return render_plan_result(result, options) if action == :plan

      puts JSON.generate(result)
    end

    def render_plan_result(result, options)
      return puts(JSON.generate(result)) if options[:json]

      summary = result.fetch(:changeset).fetch(:summary)
      puts plan_summary_line(summary)
      render_plan_changes(result.fetch(:changeset).fetch(:changes))
    end

    def execute(action, **options)
      render_result(action, runner.dispatch(action, **options), options)
    rescue Errors::Error => e
      render_error(e)
      exit(e.exit_code)
    rescue StandardError => e
      internal = Errors::InternalError.new(e.message)
      render_error(internal)
      exit(internal.exit_code)
    end

    def plan_summary_line(summary)
      "Plan summary: create=#{summary.fetch(:create)} update=#{summary.fetch(:update)} " \
        "delete=#{summary.fetch(:delete)} no_change=#{summary.fetch(:no_change)}"
    end

    def render_plan_changes(changes)
      changes.each do |change|
        puts "#{change.fetch(:action).upcase} #{change.fetch(:identity)}"
      end
    end

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
