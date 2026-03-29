# frozen_string_literal: true

require 'json'
require_relative 'spec_helper'

RSpec.describe 'umgr commands', :cli do
  let(:executable) { File.expand_path('../../exe/umgr', __dir__) }

  command_invocations = {
    'validate' => '--config users.yml'
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

  it 'returns not_initialized for show when state is missing' do
    run_command("#{executable} show")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)
    expect(parsed['ok']).to eq(true)
    expect(parsed['status']).to eq('not_initialized')
    expect(parsed['state']).to eq(nil)
  end

  it 'returns current state for show when state exists' do
    write_file(
      '.umgr/state.json',
      JSON.generate(version: 1, resources: [{ provider: 'github', type: 'user', name: 'alice' }])
    )
    run_command("#{executable} show")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)
    expect(parsed['ok']).to eq(true)
    expect(parsed['status']).to eq('ok')
    expect(parsed['state']).to eq(
      'version' => 1,
      'resources' => [{ 'provider' => 'github', 'type' => 'user', 'name' => 'alice' }]
    )
  end

  it 'initializes state on init' do
    run_command("#{executable} init")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)
    expect(parsed['ok']).to eq(true)
    expect(parsed['status']).to eq('initialized')
    expect(parsed['state']).to eq('version' => 1, 'resources' => [])
    state_path = parsed['state_path']
    expect(state_path).to end_with('/.umgr/state.json')
    expect(File.file?(state_path)).to eq(true)
  end

  it 'returns already_initialized when state file exists' do
    write_file('.umgr/state.json', JSON.generate(version: 1, resources: []))
    run_command("#{executable} init")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)
    expect(parsed['ok']).to eq(true)
    expect(parsed['status']).to eq('already_initialized')
    expect(parsed['state']).to eq('version' => 1, 'resources' => [])
  end

  it 'passes config option to validate' do
    write_file('users.yml', "version: 1\nresources: []\n")
    run_command("#{executable} validate --config users.yml")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)
    expect(parsed['options']['config']).to end_with('users.yml')
  end

  it 'returns planned changeset for desired vs current state' do
    write_file(
      'users.yml',
      <<~YAML
        version: 1
        resources:
          - provider: echo
            type: user
            name: alice
            attributes:
              team: platform
          - provider: echo
            type: user
            name: carla
      YAML
    )
    write_file(
      '.umgr/state.json',
      JSON.generate(
        version: 1,
        resources: [
          { provider: 'echo', type: 'user', name: 'alice', attributes: { team: 'infra' } },
          { provider: 'echo', type: 'user', name: 'bob' }
        ]
      )
    )

    run_command("#{executable} plan --config users.yml")

    expect(last_command_started).to have_exit_status(0)
    lines = last_command_started.stdout.lines.map(&:strip).reject(&:empty?)

    expect(lines.first).to eq('Drift detected: yes (changes=3)')
    expect(lines[1]).to eq('Plan summary: create=1 update=1 delete=1 no_change=0')
    expect(lines[2..]).to eq(
      [
        'UPDATE echo.user.alice',
        'DELETE echo.user.bob',
        'CREATE echo.user.carla'
      ]
    )
  end

  it 'applies desired state and returns applied result as json' do
    write_file(
      'users.yml',
      <<~YAML
        version: 1
        resources:
          - provider: echo
            type: user
            name: alice
            attributes:
              team: platform
      YAML
    )
    write_file(
      '.umgr/state.json',
      JSON.generate(
        version: 1,
        resources: [{ provider: 'echo', type: 'user', name: 'alice', attributes: { team: 'infra' } }]
      )
    )

    run_command("#{executable} apply --config users.yml")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)

    expect(parsed['ok']).to eq(true)
    expect(parsed['action']).to eq('apply')
    expect(parsed['status']).to eq('applied')
    expect(parsed.fetch('changeset').fetch('summary')).to eq(
      'create' => 0,
      'update' => 1,
      'delete' => 0,
      'no_change' => 0
    )
    expect(parsed.fetch('state').fetch('resources').first.fetch('attributes')).to eq('team' => 'platform')
    expect(parsed.fetch('apply_results').first.fetch('status')).to eq('applied')
    expect(parsed.fetch('idempotency')).to eq(
      'checked' => true,
      'stable' => true,
      'summary' => {
        'create' => 0,
        'update' => 0,
        'delete' => 0,
        'no_change' => 1
      }
    )
  end

  it 'imports current users and persists imported state as json' do
    write_file(
      'users.yml',
      <<~YAML
        version: 1
        resources:
          - provider: echo
            type: user
            name: alice
            attributes:
              team: platform
      YAML
    )

    run_command("#{executable} import --config users.yml")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)

    expect(parsed['ok']).to eq(true)
    expect(parsed['action']).to eq('import')
    expect(parsed['status']).to eq('imported')
    expect(parsed['imported_count']).to eq(1)
    expect(parsed.fetch('state').fetch('resources')).to eq(
      [
        {
          'provider' => 'echo',
          'type' => 'user',
          'name' => 'alice',
          'attributes' => { 'team' => 'platform' },
          'identity' => 'echo.user.alice'
        }
      ]
    )
  end

  it 'returns no drift when plan is run after apply for the same config' do
    write_file(
      'users.yml',
      <<~YAML
        version: 1
        resources:
          - provider: echo
            type: user
            name: alice
            attributes:
              team: platform
      YAML
    )
    write_file('.umgr/state.json', JSON.generate(version: 1, resources: []))

    run_command("#{executable} apply --config users.yml")
    expect(last_command_started).to have_exit_status(0)

    run_command("#{executable} plan --config users.yml")

    expect(last_command_started).to have_exit_status(0)
    lines = last_command_started.stdout.lines.map(&:strip).reject(&:empty?)
    expect(lines.first).to eq('Drift detected: no (changes=0)')
    expect(lines[1]).to eq('Plan summary: create=0 update=0 delete=0 no_change=1')
    expect(lines[2..]).to eq(['NO_CHANGE echo.user.alice'])
  end

  it 'renders plan output as json when --json is provided' do
    write_file(
      'users.yml',
      <<~YAML
        version: 1
        resources:
          - provider: echo
            type: user
            name: alice
      YAML
    )

    run_command("#{executable} plan --config users.yml --json")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)

    expect(parsed['ok']).to eq(true)
    expect(parsed['action']).to eq('plan')
    expect(parsed['status']).to eq('planned')
    expect(parsed.fetch('drift')).to eq(
      'detected' => true,
      'change_count' => 1,
      'actions' => {
        'create' => 1,
        'update' => 0,
        'delete' => 0
      }
    )
    expect(parsed.fetch('changeset').fetch('summary')).to eq(
      'create' => 1,
      'update' => 0,
      'delete' => 0,
      'no_change' => 0
    )
  end

  it 'includes github provider plan details in json plan output' do
    write_file(
      'users.yml',
      <<~YAML
        version: 1
        resources:
          - provider: github
            type: user
            name: alice
            org: acme
            token: secret
            teams:
              - admins
              - security
      YAML
    )
    write_file(
      '.umgr/state.json',
      JSON.generate(
        version: 1,
        resources: [
          { provider: 'github', type: 'user', name: 'alice', org: 'acme', teams: %w[admins platform] }
        ]
      )
    )

    run_command("#{executable} plan --config users.yml --json")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)
    change = parsed.fetch('changeset').fetch('changes').find { |item| item['identity'] == 'github.user.alice' }

    expect(change['action']).to eq('update')
    expect(change.fetch('provider_plan')).to include(
      'provider' => 'github',
      'organization_action' => 'keep',
      'status' => 'planned'
    )
    expect(change.fetch('provider_plan').fetch('team_actions')).to eq(
      'add' => ['security'],
      'remove' => ['platform'],
      'unchanged' => ['admins']
    )
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

  it 'returns validation error when provider is unknown' do
    write_file(
      'users.yml',
      <<~YAML
        version: 1
        resources:
          - provider: atlassian
            type: user
            name: alice
      YAML
    )

    run_command("#{executable} validate --config users.yml")

    expect(last_command_started).to have_exit_status(Umgr::Errors::ValidationError::EXIT_CODE)
    error_line = last_command_started.stderr.lines.map(&:strip).reject(&:empty?).last
    parsed = JSON.parse(error_line)
    expect(parsed['error']['type']).to eq('Umgr::Errors::ValidationError')
    expect(parsed['error']['message']).to match(/Unknown provider\(s\) for validate: atlassian/)
  end

  it 'returns validation error when github provider config is invalid' do
    write_file(
      'users.yml',
      <<~YAML
        version: 1
        resources:
          - provider: github
            type: user
            name: alice
            token_env: GITHUB_TOKEN
      YAML
    )

    run_command("#{executable} validate --config users.yml")

    expect(last_command_started).to have_exit_status(Umgr::Errors::ValidationError::EXIT_CODE)
    error_line = last_command_started.stderr.lines.map(&:strip).reject(&:empty?).last
    parsed = JSON.parse(error_line)
    expect(parsed['error']['type']).to eq('Umgr::Errors::ValidationError')
    expect(parsed['error']['message']).to match(/requires non-empty `org`/)
  end

  it 'preserves attributes and provider-specific resource fields with echo provider' do
    write_file(
      'users.yml',
      <<~YAML
        version: 1
        resources:
          - provider: echo
            type: user
            name: alice
            attributes:
              email: alice@example.com
              first_name: Alice
            org: platform
            roles:
              - admin
              - writer
      YAML
    )

    run_command("#{executable} validate --config users.yml")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)
    resource = parsed.fetch('options').fetch('desired_state').fetch('resources').first

    expect(resource['attributes']).to eq(
      'email' => 'alice@example.com',
      'first_name' => 'Alice'
    )
    expect(resource['org']).to eq('platform')
    expect(resource['roles']).to eq(%w[admin writer])
  end

  it 'includes canonical identity for desired_state resources' do
    write_file(
      'users.yml',
      <<~YAML
        version: 1
        resources:
          - provider: echo
            type: user
            name: alice
      YAML
    )

    run_command("#{executable} validate --config users.yml")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)
    resource = parsed.fetch('options').fetch('desired_state').fetch('resources').first
    expect(resource['identity']).to eq('echo.user.alice')
  end

  it 'returns state backend path for commands' do
    run_command("#{executable} show")

    expect(last_command_started).to have_exit_status(0)
    parsed = JSON.parse(last_command_started.stdout)
    expect(parsed['state_path']).to end_with('/.umgr/state.json')
  end
end
