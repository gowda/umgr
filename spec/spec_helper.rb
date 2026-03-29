# frozen_string_literal: true

require 'simplecov'

SimpleCov.command_name(ENV.fetch('SIMPLECOV_COMMAND_NAME', 'rspec'))
SimpleCov.start do
  enable_coverage :branch
  add_filter '/spec/'
end

require 'umgr'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
