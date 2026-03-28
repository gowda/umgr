# frozen_string_literal: true

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
  end
end
