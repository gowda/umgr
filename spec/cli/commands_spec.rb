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
      write_file('users.yml', "version: 1\nresources: []\n") if args.include?('--config users.yml')
      run_command("#{executable} #{command} #{args}".strip)

      expect(last_command_started).to have_exit_status(0)
      parsed = JSON.parse(last_command_started.stdout)
      expect(parsed['action']).to eq(command)
      expect(parsed['status']).to eq('not_implemented')
    end
  end

  it 'passes config option to validate' do
    write_file('users.yml', "version: 1\nresources: []\n")
    run_command("#{executable} validate --config users.yml")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)
    expect(parsed['options']['config']).to end_with('users.yml')
  end

  it 'auto-discovers config for validate when --config is omitted' do
    write_file('umgr.yml', "version: 1\nresources: []\n")
    run_command("#{executable} validate")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)
    expect(parsed['options']['config']).to end_with('umgr.yml')
  end

  it 'uses --config override when discovery candidates exist' do
    write_file('umgr.yml', "version: 1\nresources: []\n")
    write_file('custom.json', "{\"version\":1,\"resources\":[]}\n")
    run_command("#{executable} validate --config custom.json")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)
    expect(parsed['options']['config']).to end_with('custom.json')
  end

  it 'maps validation error to CLI exit code' do
    run_command("#{executable} validate")

    expect(last_command_started).to have_exit_status(Umgr::Errors::ValidationError::EXIT_CODE)
    error_line = last_command_started.stderr.lines.map(&:strip).reject(&:empty?).last
    parsed = JSON.parse(error_line)
    expect(parsed['ok']).to eq(false)
    expect(parsed['error']['type']).to eq('Umgr::Errors::ValidationError')
  end

  it 'returns validation error when schema is invalid' do
    write_file('invalid.yml', "version: 1\nresources:\n  - provider: github\n")
    run_command("#{executable} validate --config invalid.yml")

    expect(last_command_started).to have_exit_status(Umgr::Errors::ValidationError::EXIT_CODE)
    error_line = last_command_started.stderr.lines.map(&:strip).reject(&:empty?).last
    parsed = JSON.parse(error_line)
    expect(parsed['error']['type']).to eq('Umgr::Errors::ValidationError')
    expect(parsed['error']['message']).to match(/missing required string field `type`/)
  end

  it 'returns validation error when version is invalid' do
    write_file('invalid.yml', "version: banana\nresources: []\n")
    run_command("#{executable} validate --config invalid.yml")

    expect(last_command_started).to have_exit_status(Umgr::Errors::ValidationError::EXIT_CODE)
    error_line = last_command_started.stderr.lines.map(&:strip).reject(&:empty?).last
    parsed = JSON.parse(error_line)
    expect(parsed['error']['type']).to eq('Umgr::Errors::ValidationError')
    expect(parsed['error']['message']).to match(/`version` must be a positive integer/)
  end
end
