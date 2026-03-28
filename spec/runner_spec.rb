# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'

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
    File.write('users.yml', "version: 1\nresources: []\n")
    result = runner.dispatch(:validate, config: 'users.yml')

    expect(result[:options][:config]).to end_with('users.yml')
  ensure
    FileUtils.rm_f('users.yml')
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
