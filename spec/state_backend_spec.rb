# frozen_string_literal: true

require 'tmpdir'

RSpec.describe Umgr::StateBackend do
  it 'resolves state path under .umgr/state.json by default' do
    Dir.mktmpdir do |tmp_dir|
      backend = described_class.new(root_dir: tmp_dir)

      expect(backend.path).to eq(File.join(tmp_dir, '.umgr', 'state.json'))
    end
  end

  it 'writes and reads state data' do
    Dir.mktmpdir do |tmp_dir|
      backend = described_class.new(root_dir: tmp_dir)
      payload = {
        version: 1,
        resources: [
          { provider: 'github', type: 'user', name: 'alice' }
        ]
      }

      written_path = backend.write(payload)

      expect(written_path).to eq(backend.path)
      expect(backend.read).to eq(payload)
    end
  end

  it 'removes temporary files after atomic write' do
    Dir.mktmpdir do |tmp_dir|
      backend = described_class.new(root_dir: tmp_dir)
      backend.write(version: 1, resources: [])

      temp_files = Dir.glob(File.join(tmp_dir, '.umgr', 'state.json.tmp-*'))
      expect(temp_files).to eq([])
    end
  end

  it 'deletes persisted state file' do
    Dir.mktmpdir do |tmp_dir|
      backend = described_class.new(root_dir: tmp_dir)
      backend.write(version: 1, resources: [])

      backend.delete

      expect(File.file?(backend.path)).to eq(false)
      expect(backend.read).to eq(nil)
    end
  end
end
