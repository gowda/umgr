# frozen_string_literal: true

RSpec.describe Umgr::Runner do
  it 'is instantiable' do
    expect(described_class.new).to be_a(described_class)
  end

  it 'returns ok for #ping' do
    expect(described_class.new.ping).to eq(:ok)
  end
end
