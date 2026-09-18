require 'spec_helper'

describe 'RuStore lifecycle actions' do
  let(:helper) { Fastlane::Helper::UploadToRuStoreHelper }
  let(:fastlane_error) { FastlaneCore::Interface::FastlaneError }
  let(:auth) { { package_name: 'com.example.app', key_id: 'kid', private_key: 'pem' } }

  before do
    allow(helper).to receive(:fetch_token).and_return('jwe')
  end

  describe Fastlane::Actions::RustoreVersionStatusAction do
    it 'returns the latest version and fills the lane context' do
      allow(helper).to receive(:latest_version).and_return(
        { 'versionId' => 42, 'versionCode' => 7, 'versionName' => '1.0', 'versionStatus' => 'ACTIVE' }
      )

      result = described_class.run(auth.merge(testing_type: 'ALL'))

      expect(result['versionId']).to eq(42)
      expect(Fastlane::Actions.lane_context[Fastlane::Actions::SharedValues::RUSTORE_VERSION_STATUS]).to eq('ACTIVE')
    end

    it 'returns nil when the application has no versions' do
      allow(helper).to receive(:latest_version).and_return(nil)
      expect(described_class.run(auth)).to be_nil
    end
  end

  describe Fastlane::Actions::RustorePublishVersionAction do
    it 'publishes the given version' do
      allow(helper).to receive(:publish_version)

      described_class.run(auth.merge(version_id: 5))

      expect(helper).to have_received(:publish_version).with(hash_including(version_id: 5))
    end

    it 'falls back to the latest version' do
      allow(helper).to receive(:latest_version).and_return({ 'versionId' => 9 })
      allow(helper).to receive(:publish_version)

      described_class.run(auth)

      expect(helper).to have_received(:publish_version).with(hash_including(version_id: 9))
    end

    it 'fails when there is nothing to publish' do
      allow(helper).to receive(:latest_version).and_return(nil)

      expect { described_class.run(auth) }.to raise_error(fastlane_error, /нет ни одной версии/)
    end
  end

  describe Fastlane::Actions::RustoreArchiveVersionAction do
    it 'archives the given version' do
      allow(helper).to receive(:archive_version)

      described_class.run(auth.merge(version_id: 3))

      expect(helper).to have_received(:archive_version).with(hash_including(version_id: 3))
    end
  end

  describe Fastlane::Actions::RustorePublishSettingsAction do
    it 'passes only the settings provided' do
      allow(helper).to receive(:update_publish_settings)

      described_class.run(auth.merge(version_id: 3, partial_value: 50))

      expect(helper).to have_received(:update_publish_settings).with(hash_including(partial_value: 50, version_id: 3))
    end

    it 'refuses an empty update' do
      expect { described_class.run(auth.merge(version_id: 3)) }
        .to raise_error(fastlane_error, /ни одной настройки/)
    end
  end

  describe 'plugin surface' do
    it 'registers every action with fastlane' do
      names = Fastlane::Actions.constants.map(&:to_s)
      expect(names).to include(
        'UploadToRuStoreAction', 'RustoreVersionStatusAction',
        'RustorePublishVersionAction', 'RustoreArchiveVersionAction',
        'RustorePublishSettingsAction'
      )
    end

    it 'gives every action a description, details and examples' do
      [
        Fastlane::Actions::UploadToRuStoreAction,
        Fastlane::Actions::RustoreVersionStatusAction,
        Fastlane::Actions::RustorePublishVersionAction,
        Fastlane::Actions::RustoreArchiveVersionAction,
        Fastlane::Actions::RustorePublishSettingsAction
      ].each do |action|
        expect(action.description).to be_a(String)
        expect(action.details).to be_a(String)
        expect(action.example_code).to be_an(Array)
        expect(action.available_options).to all(be_a(FastlaneCore::ConfigItem))
      end
    end
  end
end
