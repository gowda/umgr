# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'securerandom'

module Umgr
  class StateBackend
    DEFAULT_STATE_DIR = '.umgr'
    DEFAULT_STATE_FILE = 'state.json'

    def initialize(root_dir: Dir.pwd, state_dir: DEFAULT_STATE_DIR, state_file: DEFAULT_STATE_FILE)
      @root_dir = root_dir
      @state_dir = state_dir
      @state_file = state_file
    end

    def path
      File.join(root_dir, state_dir, state_file)
    end

    def read
      return nil unless File.file?(path)

      JSON.parse(File.read(path), symbolize_names: true)
    end

    def write(state)
      ensure_state_directory!
      temp_path = "#{path}.tmp-#{SecureRandom.hex(8)}"
      write_temp_state_file(temp_path, state)
      File.rename(temp_path, path)
      path
    ensure
      FileUtils.rm_f(temp_path)
    end

    def delete
      FileUtils.rm_f(path)
      path
    end

    private

    attr_reader :root_dir, :state_dir, :state_file

    def ensure_state_directory!
      FileUtils.mkdir_p(File.dirname(path))
    end

    def write_temp_state_file(temp_path, state)
      File.open(temp_path, 'w') do |file|
        file.write(JSON.pretty_generate(state))
        file.flush
        file.fsync
      end
    end
  end
end
