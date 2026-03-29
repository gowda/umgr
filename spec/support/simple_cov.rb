# frozen_string_literal: true

require 'simplecov'

SimpleCov.command_name(ENV.fetch('SIMPLECOV_COMMAND_NAME', 'rspec'))
SimpleCov.start do
  enable_coverage :branch
  add_filter '/spec/'
end
