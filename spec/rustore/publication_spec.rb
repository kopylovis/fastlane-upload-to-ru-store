require 'spec_helper'

describe Fastlane::Helper::Rustore::Publication do
  let(:config_error) { Fastlane::Helper::Rustore::ConfigurationError }
  let(:in_three_days) { (Time.now + (3 * 24 * 3600)).iso8601 }

  describe '.draft_payload' do
    it 'normalises the DELAYED date to the format RuStore documents' do
      payload = described_class.draft_payload(publish_type: 'DELAYED', publish_datetime: '2099-06-01T12:00:00.123+03:00')

      expect(payload).to eq(publishType: 'DELAYED', publishDateTime: '2099-06-01T12:00:00+03:00')
    end

    it 'drops the date for other publication types' do
      payload = described_class.draft_payload(publish_type: 'MANUAL', publish_datetime: in_three_days)

      expect(payload).to eq(publishType: 'MANUAL')
    end

    it 'refuses a staged rollout with DELAYED' do
      expect { described_class.draft_payload(publish_type: 'DELAYED', publish_datetime: in_three_days, partial_value: 10) }
        .to raise_error(config_error, /MANUAL и INSTANTLY/)
    end

    it 'refuses a date without time or zone' do
      expect { described_class.draft_payload(publish_type: 'DELAYED', publish_datetime: '2099-06-01') }
        .to raise_error(config_error, /часовой пояс/)
    end

    it 'refuses a date in the past' do
      expect { described_class.draft_payload(publish_type: 'DELAYED', publish_datetime: '2020-01-01T00:00:00Z') }
        .to raise_error(config_error, /в прошлом/)
    end
  end

  describe '.settings_payload' do
    it 'refuses a percentage together with a publication type' do
      expect { described_class.settings_payload(publish_type: 'INSTANTLY', partial_value: 50) }
        .to raise_error(config_error, /либо partial_value/)
    end

    it 'refuses a date without DELAYED' do
      expect { described_class.settings_payload(publish_datetime: in_three_days) }
        .to raise_error(config_error, /DELAYED/)
    end

    it 'requires a date for DELAYED' do
      expect { described_class.settings_payload(publish_type: 'DELAYED') }.to raise_error(config_error, /обязателен/)
    end

    it 'passes a percentage alone' do
      expect(described_class.settings_payload(partial_value: '75')).to eq(partialValue: 75)
    end
  end

  describe '.check_window!' do
    it 'accepts three days ahead' do
      expect { described_class.check_window!(in_three_days) }.not_to raise_error
    end

    it 'refuses less than 24 hours ahead' do
      expect { described_class.check_window!((Time.now + 3600).iso8601) }.to raise_error(config_error, /24 часа/)
    end

    it 'refuses more than 60 days ahead' do
      expect { described_class.check_window!((Time.now + (61 * 24 * 3600)).iso8601) }.to raise_error(config_error, /60 дней/)
    end
  end

  describe '.priority!' do
    it 'accepts 0 to 5' do
      expect(described_class.priority!(5)).to eq(5)
    end

    it 'refuses 6' do
      expect { described_class.priority!(6) }.to raise_error(config_error, /от 0 до 5/)
    end
  end
end
