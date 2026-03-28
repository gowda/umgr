# frozen_string_literal: true

require 'aruba/rspec'
require 'umgr'

RSpec.configure do |config|
  config.include Aruba::Api
  config.before(:each, :cli) do
    setup_aruba
    project_lib = File.expand_path('../../lib', __dir__)
    set_environment_variable('RUBYLIB', project_lib)
  end
end
