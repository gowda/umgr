# frozen_string_literal: true

require_relative 'spec_helper'

RSpec.describe 'umgr help', :cli do
  it 'shows available commands' do
    executable = File.expand_path('../../exe/umgr', __dir__)
    lib_path = File.expand_path('../../lib', __dir__)

    run_command("ruby -I #{lib_path} #{executable} help")

    expect(last_command_started).to have_output(/Commands:/)
    expect(last_command_started).to have_exit_status(0)
  end
end
