# frozen_string_literal: true

RSpec.describe Umgr::Provider do
  subject(:provider) { described_class.new }

  it 'raises for validate by default' do
    expect { provider.validate(resource: {}) }
      .to raise_error(Umgr::Errors::AbstractMethodError, /must implement #validate/)
  end

  it 'raises for current by default' do
    expect { provider.current(resource: {}) }
      .to raise_error(Umgr::Errors::AbstractMethodError, /must implement #current/)
  end

  it 'raises for plan by default' do
    expect { provider.plan(desired: {}, current: {}) }
      .to raise_error(Umgr::Errors::AbstractMethodError, /must implement #plan/)
  end

  it 'raises for apply by default' do
    expect { provider.apply(changeset: {}) }
      .to raise_error(Umgr::Errors::AbstractMethodError, /must implement #apply/)
  end
end
