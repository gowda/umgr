# frozen_string_literal: true

require 'json'
require_relative 'spec_helper'

RSpec.describe 'umgr commands', :cli do
  let(:executable) { File.expand_path('../../exe/umgr', __dir__) }
  let(:lib_path) { File.expand_path('../../lib', __dir__) }

  %w[init validate plan apply show import].each do |command|
    it "dispatches #{command}" do
      run_command("ruby -I #{lib_path} #{executable} #{command}")

      expect(last_command_started).to have_exit_status(0)
      parsed = JSON.parse(last_command_started.stdout)
      expect(parsed['action']).to eq(command)
      expect(parsed['status']).to eq('not_implemented')
    end
  end

  it 'passes config option to validate' do
    run_command("ruby -I #{lib_path} #{executable} validate --config users.yml")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)
    expect(parsed['options']).to eq({ 'config' => 'users.yml' })
  end
end
