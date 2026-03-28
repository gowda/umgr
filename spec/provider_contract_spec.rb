# frozen_string_literal: true

RSpec.describe Umgr::ProviderContract do
  let(:provider_class) do
    Class.new do
      def validate(resource:); end
      def current(resource:); end
      def plan(desired:, current:); end
      def apply(changeset:); end
    end
  end

  it 'accepts providers implementing the contract' do
    provider = provider_class.new

    expect(described_class.validate!(provider)).to eq(provider)
  end

  it 'raises when required methods are missing' do
    invalid_provider = Object.new

    expect { described_class.validate!(invalid_provider) }
      .to raise_error(ArgumentError, /must implement concrete methods/)
  end

  it 'raises when provider uses abstract base implementations' do
    abstract_provider = Umgr::Provider.new

    expect { described_class.validate!(abstract_provider) }
      .to raise_error(ArgumentError, /must implement concrete methods/)
  end
end
