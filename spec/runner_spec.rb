# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Umgr::Runner do
  subject(:runner) { described_class.new }

  it 'is instantiable' do
    expect(runner).to be_a(described_class)
  end

  it 'returns ok for #ping' do
    expect(runner.ping).to eq(:ok)
  end

  it 'dispatches all supported actions' do
    %i[init show].each do |action|
      result = runner.dispatch(action)

      expect(result[:action]).to eq(action.to_s)
      expect(result[:status]).to eq('not_implemented')
      expect(result[:ok]).to eq(false)
    end
  end

  it 'passes options to dispatched methods' do
    Dir.mktmpdir do |tmp_dir|
      File.write(File.join(tmp_dir, 'users.yml'), "version: 1\nresources: []\n")

      result = Dir.chdir(tmp_dir) { runner.dispatch(:validate, config: 'users.yml') }

      expect(result[:options][:config]).to end_with('/users.yml')
    end
  end

  it 'auto-discovers config when not explicitly provided' do
    Dir.mktmpdir do |tmp_dir|
      config_path = File.join(tmp_dir, 'umgr.yml')
      File.write(config_path, "version: 1\nresources: []\n")

      result = Dir.chdir(tmp_dir) { runner.dispatch(:validate) }

      expect(result[:options][:config]).to end_with('/umgr.yml')
    end
  end

  it 'uses explicit config path over auto-discovery candidates' do
    Dir.mktmpdir do |tmp_dir|
      File.write(File.join(tmp_dir, 'umgr.yml'), "version: 1\nresources: []\n")
      explicit_path = File.join(tmp_dir, 'custom.json')
      File.write(explicit_path, "{\"version\":1,\"resources\":[]}\n")

      result = Dir.chdir(tmp_dir) { runner.dispatch(:validate, config: 'custom.json') }

      expect(result[:options][:config]).to end_with('/custom.json')
    end
  end

  it 'raises validation error when required config is missing' do
    expect { runner.dispatch(:validate) }
      .to raise_error(Umgr::Errors::ValidationError, /config/)
  end

  it 'raises validation error when explicit config is missing' do
    expect { runner.dispatch(:validate, config: 'does-not-exist.yml') }
      .to raise_error(Umgr::Errors::ValidationError, /Config file not found/)
  end

  it 'raises validation error when version type is invalid' do
    Dir.mktmpdir do |tmp_dir|
      File.write(File.join(tmp_dir, 'invalid.yml'), "version: banana\nresources: []\n")

      expect do
        Dir.chdir(tmp_dir) { runner.dispatch(:validate, config: 'invalid.yml') }
      end.to raise_error(Umgr::Errors::ValidationError, /`version` must be a positive integer/)
    end
  end

  it 'raises validation error when top-level required keys are missing' do
    Dir.mktmpdir do |tmp_dir|
      File.write(File.join(tmp_dir, 'invalid.yml'), "resources: []\n")

      expect do
        Dir.chdir(tmp_dir) { runner.dispatch(:validate, config: 'invalid.yml') }
      end.to raise_error(Umgr::Errors::ValidationError, /Missing required key `version`/)
    end
  end

  it 'raises validation error when resource required fields are missing' do
    Dir.mktmpdir do |tmp_dir|
      File.write(File.join(tmp_dir, 'invalid.yml'), "version: 1\nresources:\n  - provider: github\n")

      expect do
        Dir.chdir(tmp_dir) { runner.dispatch(:validate, config: 'invalid.yml') }
      end.to raise_error(Umgr::Errors::ValidationError, /missing required string field `type`/)
    end
  end

  it 'preserves attributes and provider-specific resource fields in desired_state' do
    Dir.mktmpdir do |tmp_dir|
      File.write(
        File.join(tmp_dir, 'users.yml'),
        <<~YAML
          version: 1
          resources:
            - provider: github
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

      result = Dir.chdir(tmp_dir) { runner.dispatch(:validate, config: 'users.yml') }
      resource = result[:options][:desired_state]['resources'].first

      expect(resource['attributes']).to eq(
        'email' => 'alice@example.com',
        'first_name' => 'Alice'
      )
      expect(resource['org']).to eq('platform')
      expect(resource['roles']).to eq(%w[admin writer])
    end
  end

  it 'keeps action methods private' do
    described_class::ACTIONS.each do |action|
      expect(runner).not_to respond_to(action)
    end
  end

  it 'raises for unsupported actions' do
    expect { runner.dispatch(:unknown) }
      .to raise_error(Umgr::Errors::UnknownActionError, /Unknown action/)
  end
end
