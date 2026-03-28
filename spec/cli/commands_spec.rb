# frozen_string_literal: true

require 'json'
require_relative 'spec_helper'

RSpec.describe 'umgr commands', :cli do
  let(:executable) { File.expand_path('../../exe/umgr', __dir__) }

  command_invocations = {
    'init' => '',
    'validate' => '--config users.yml',
    'plan' => '--config users.yml',
    'apply' => '--config users.yml',
    'show' => '',
    'import' => '--config users.yml'
  }

  command_invocations.each do |command, args|
    it "dispatches #{command}" do
      run_command("#{executable} #{command} #{args}".strip)

      expect(last_command_started).to have_exit_status(0)
      parsed = JSON.parse(last_command_started.stdout)
      expect(parsed['action']).to eq(command)
      expect(parsed['status']).to eq('not_implemented')
    end
  end

  it 'passes config option to validate' do
    run_command("#{executable} validate --config users.yml")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)
    expect(parsed['options']).to eq({ 'config' => 'users.yml' })
  end

  it 'maps validation error to CLI exit code' do
    run_command("#{executable} validate")

    expect(last_command_started).to have_exit_status(Umgr::Errors::ValidationError::EXIT_CODE)
    parsed = JSON.parse(last_command_started.stdout)
    expect(parsed['ok']).to eq(false)
    expect(parsed['error']['type']).to eq('Umgr::Errors::ValidationError')
  end
end
