# frozen_string_literal: true

RSpec.describe Umgr::Runner do
  subject(:runner) { described_class.new }

  it 'is instantiable' do
    expect(runner).to be_a(described_class)
  end

  it 'returns ok for #ping' do
    expect(runner.ping).to eq(:ok)
  end

  it 'dispatches all supported actions' do
    described_class::ACTIONS.each do |action|
      result = runner.dispatch(action)

      expect(result[:action]).to eq(action.to_s)
      expect(result[:status]).to eq('not_implemented')
      expect(result[:ok]).to eq(false)
    end
  end

  it 'passes options to dispatched methods' do
    result = runner.dispatch(:validate, config: 'users.yml')

    expect(result[:options]).to eq({ config: 'users.yml' })
  end

  it 'raises for unsupported actions' do
    expect { runner.dispatch(:unknown) }.to raise_error(ArgumentError, /Unknown action/)
  end
end
