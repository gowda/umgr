# frozen_string_literal: true

RSpec.describe Umgr::ProviderRegistry do
  let(:registry) { described_class.new }
  let(:provider) do
    Class.new do
      def validate(resource:); end
      def current(resource:); end
      def plan(desired:, current:); end
      def apply(changeset:); end
    end.new
  end

  it 'registers and fetches providers by normalized name' do
    registry.register('github', provider)

    expect(registry.fetch(:github)).to eq(provider)
    expect(registry.fetch('github')).to eq(provider)
  end

  it 'lists registered provider names' do
    registry.register(:slack, provider)
    registry.register('github', provider)

    expect(registry.names).to eq(%i[github slack])
  end

  it 'raises for empty provider names' do
    expect { registry.register(' ', provider) }
      .to raise_error(Umgr::Errors::ProviderContractError, /Provider name must be a non-empty/)
  end

  it 'raises when provider contract is incomplete' do
    expect { registry.register('github', Object.new) }
      .to raise_error(Umgr::Errors::ProviderContractError, /must implement/)
  end
end
