# frozen_string_literal: true

Dir[File.expand_path('support/**/*.rb', __dir__)].each { |file| require file }

require 'umgr'

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
