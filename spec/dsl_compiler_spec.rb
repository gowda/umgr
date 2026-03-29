# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Umgr::DslCompiler do
  it 'compiles DSL file into validated config hash' do
    Dir.mktmpdir do |tmp_dir|
      dsl_path = File.join(tmp_dir, 'umgr.rb')
      File.write(
        dsl_path,
        <<~RUBY
          umgr do
            version = 1
          end

          resource provider: 'echo', type: 'user', name: 'alice', attributes: { team: 'platform' }
        RUBY
      )

      result = described_class.compile_file(dsl_path)

      expect(result).to eq(
        {
          'version' => 1,
          'resources' => [
            {
              'provider' => 'echo',
              'type' => 'user',
              'name' => 'alice',
              'attributes' => { 'team' => 'platform' }
            }
          ]
        }
      )
    end
  end

  it 'raises validation error when DSL file is missing' do
    expect do
      described_class.compile_file('/tmp/not-here-umgr.rb')
    end.to raise_error(Umgr::Errors::ValidationError, /DSL file not found/)
  end

  it 'supports branching and looping helpers in DSL' do
    Dir.mktmpdir do |tmp_dir|
      dsl_path = File.join(tmp_dir, 'umgr.rb')
      File.write(
        dsl_path,
        <<~RUBY
          umgr do
            version = 1
          end

          for_each(%w[alice bob]) do |name|
            resource provider: 'echo', type: 'user', name: name
          end

          if_enabled(true) do
            resource provider: 'echo', type: 'user', name: 'carol'
          end

          if_enabled(false) do
            resource provider: 'echo', type: 'user', name: 'skip-me'
          end
        RUBY
      )

      result = described_class.compile_file(dsl_path)
      resources = result.fetch('resources')

      expect(resources.map { |resource| resource.fetch('name') }).to eq(%w[alice bob carol])
      expect(resources).to all(include('provider' => 'echo', 'type' => 'user'))
    end
  end

  it 'supports provider matrix and deterministic ordering in compiled output' do
    Dir.mktmpdir do |tmp_dir|
      dsl_path = File.join(tmp_dir, 'umgr.rb')
      File.write(
        dsl_path,
        <<~RUBY
          umgr do
            version = 1
          end

          provider_matrix(
            providers: %w[slack github],
            accounts: [
              { name: 'zoe', attributes: { team: 'eng' } },
              { name: 'amy', attributes: { team: 'sales' } }
            ],
            type: :user,
            roles: ['member']
          )
        RUBY
      )

      result = described_class.compile_file(dsl_path)
      resources = result.fetch('resources')

      expect(resources.map { |resource| resource.fetch('provider') }).to eq(%w[github github slack slack])
      expect(resources.map { |resource| resource.fetch('name') }).to eq(%w[amy zoe amy zoe])
      expect(resources.first).to include(
        'provider' => 'github',
        'type' => 'user',
        'name' => 'amy',
        'roles' => ['member'],
        'attributes' => { 'team' => 'sales' }
      )
      expect(resources.last).to include(
        'provider' => 'slack',
        'type' => 'user',
        'name' => 'zoe',
        'roles' => ['member'],
        'attributes' => { 'team' => 'eng' }
      )
    end
  end

  it 'raises validation error when provider_matrix account name is missing' do
    Dir.mktmpdir do |tmp_dir|
      dsl_path = File.join(tmp_dir, 'umgr.rb')
      File.write(
        dsl_path,
        <<~RUBY
          umgr do
            version = 1
          end

          provider_matrix(
            providers: %w[github],
            accounts: [{ attributes: { team: 'eng' } }]
          )
        RUBY
      )

      expect do
        described_class.compile_file(dsl_path)
      end.to raise_error(Umgr::Errors::ValidationError, /provider_matrix account requires non-empty `name`/)
    end
  end

  it 'raises validation error when provider_matrix account name is empty' do
    Dir.mktmpdir do |tmp_dir|
      dsl_path = File.join(tmp_dir, 'umgr.rb')
      File.write(
        dsl_path,
        <<~RUBY
          umgr do
            version = 1
          end

          provider_matrix(
            providers: %w[github],
            accounts: [{ name: '', attributes: { team: 'eng' } }]
          )
        RUBY
      )

      expect do
        described_class.compile_file(dsl_path)
      end.to raise_error(Umgr::Errors::ValidationError, /provider_matrix account requires non-empty `name`/)
    end
  end

  it 'raises validation error for unsupported DSL methods' do
    Dir.mktmpdir do |tmp_dir|
      dsl_path = File.join(tmp_dir, 'umgr.rb')
      File.write(
        dsl_path,
        <<~RUBY
          umgr do
            version = 1
            system('echo should-not-run')
          end
        RUBY
      )

      expect do
        described_class.compile_file(dsl_path)
      end.to raise_error(Umgr::Errors::ValidationError, /Unsupported DSL method `system`/)
    end
  end

  it 'raises validation error when top-level umgr block is missing' do
    Dir.mktmpdir do |tmp_dir|
      dsl_path = File.join(tmp_dir, 'umgr.rb')
      File.write(dsl_path, "resource provider: 'echo', type: 'user', name: 'alice'\n")

      expect do
        described_class.compile_file(dsl_path)
      end.to raise_error(Umgr::Errors::ValidationError, /Top-level `umgr` block is required/)
    end
  end

  it 'raises validation error when resource is nested inside umgr block' do
    Dir.mktmpdir do |tmp_dir|
      dsl_path = File.join(tmp_dir, 'umgr.rb')
      File.write(
        dsl_path,
        <<~RUBY
          umgr do
            version = 1
            resource provider: 'echo', type: 'user', name: 'alice'
          end
        RUBY
      )

      expect do
        described_class.compile_file(dsl_path)
      end.to raise_error(Umgr::Errors::ValidationError, /`resource` must be declared at top-level/)
    end
  end

  it 'raises validation error when version is invoked as a method' do
    Dir.mktmpdir do |tmp_dir|
      dsl_path = File.join(tmp_dir, 'umgr.rb')
      File.write(
        dsl_path,
        <<~RUBY
          umgr do
            version 1
          end
        RUBY
      )

      expect do
        described_class.compile_file(dsl_path)
      end.to raise_error(Umgr::Errors::ValidationError, /Unsupported DSL method `version`/)
    end
  end

  it 'raises validation error for unsupported assignment inside umgr block' do
    Dir.mktmpdir do |tmp_dir|
      dsl_path = File.join(tmp_dir, 'umgr.rb')
      File.write(
        dsl_path,
        <<~RUBY
          umgr do
            version = 1
            foo = 'bar'
          end
        RUBY
      )

      expect do
        described_class.compile_file(dsl_path)
      end.to raise_error(Umgr::Errors::ValidationError, /Unsupported.*assignment/)
    end
  end
end
