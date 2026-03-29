# frozen_string_literal: true

RSpec.describe Umgr::DriftReportBuilder do
  it 'reports drift when create/update/delete counts are present' do
    report = described_class.call(create: 1, update: 2, delete: 1, no_change: 5)

    expect(report).to eq(
      detected: true,
      change_count: 4,
      actions: {
        create: 1,
        update: 2,
        delete: 1
      }
    )
  end

  it 'reports no drift when all drift actions are zero' do
    report = described_class.call(create: 0, update: 0, delete: 0, no_change: 3)

    expect(report).to eq(
      detected: false,
      change_count: 0,
      actions: {
        create: 0,
        update: 0,
        delete: 0
      }
    )
  end
end
