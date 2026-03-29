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
            version 1
            resource provider: 'echo', type: 'user', name: 'alice', attributes: { team: 'platform' }
          end
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
end
